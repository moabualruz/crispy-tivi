//! Video underlay — bridges libmpv OpenGL rendering into Slint's GL context via FBO.
//!
//! # Architecture
//! ```text
//! Slint Window
//! ├─ Layer 0: libmpv renders into our FBO (texture)
//! ├─ Layer 1: draw_underlay() blits that texture as a fullscreen quad
//! └─ Layer 2: Slint UI canvas renders on top (transparent)
//! ```
//!
//! The caller must:
//! 1. Call `VideoUnderlay::new()` from Slint's `RenderingSetup` callback (on the GL thread).
//! 2. Call `render()` + `draw_underlay()` from Slint's `BeforeRendering` callback.
//! 3. Drop `VideoUnderlay` before destroying the GL context.
//!
//! # Safety
//! All OpenGL calls and raw FFI operations are unsafe. The caller is responsible for ensuring
//! the GL context is current on the calling thread for every method.

use std::{
    ffi::{CStr, CString, c_void},
    sync::atomic::{AtomicBool, Ordering},
};

use glow::HasContext;
use libmpv_sys::{
    MPV_RENDER_API_TYPE_OPENGL, mpv_handle, mpv_opengl_fbo, mpv_opengl_init_params,
    mpv_render_context, mpv_render_context_create, mpv_render_context_free,
    mpv_render_context_render, mpv_render_context_set_update_callback, mpv_render_context_update,
    mpv_render_param, mpv_render_param_type_MPV_RENDER_PARAM_API_TYPE as PARAM_API_TYPE,
    mpv_render_param_type_MPV_RENDER_PARAM_FLIP_Y as PARAM_FLIP_Y,
    mpv_render_param_type_MPV_RENDER_PARAM_INVALID as PARAM_INVALID,
    mpv_render_param_type_MPV_RENDER_PARAM_OPENGL_FBO as PARAM_OPENGL_FBO,
    mpv_render_param_type_MPV_RENDER_PARAM_OPENGL_INIT_PARAMS as PARAM_OPENGL_INIT_PARAMS,
    mpv_render_update_flag_MPV_RENDER_UPDATE_FRAME as UPDATE_FRAME,
};

// ---------------------------------------------------------------------------
// GL proc-address trampoline
// ---------------------------------------------------------------------------

/// Context passed through the C callback for GL proc-address resolution.
/// Stores a raw pointer to the Rust closure so the trampoline can call it.
struct ProcAddrCtx {
    func: Box<dyn Fn(&CStr) -> *const c_void>,
}

/// C-callable trampoline: converts the C `name` pointer to a `&CStr` and
/// calls the stored Rust closure.
unsafe extern "C" fn get_proc_address_trampoline(
    ctx: *mut c_void,
    name: *const std::os::raw::c_char,
) -> *mut c_void {
    unsafe {
        let ctx = &*(ctx as *const ProcAddrCtx);
        // SAFETY: name is a valid null-terminated C string provided by libmpv.
        let cname = CStr::from_ptr(name);
        (ctx.func)(cname) as *mut c_void
    }
}

// ---------------------------------------------------------------------------
// Update callback trampoline
// ---------------------------------------------------------------------------

unsafe extern "C" fn update_callback(cb_ctx: *mut c_void) {
    unsafe {
        let flag = &*(cb_ctx as *const AtomicBool);
        flag.store(true, Ordering::Release);
    }
}

// ---------------------------------------------------------------------------
// Fullscreen quad shaders
// ---------------------------------------------------------------------------

const QUAD_VERT_SRC: &str = r#"#version 330 core
out vec2 v_uv;
void main() {
    // Triangle that covers the screen: indices 0,1,2
    vec2 pos[3] = vec2[](vec2(-1.0,-1.0), vec2(3.0,-1.0), vec2(-1.0,3.0));
    v_uv = pos[gl_VertexID] * 0.5 + 0.5;
    gl_Position = vec4(pos[gl_VertexID], 0.0, 1.0);
}
"#;

const QUAD_FRAG_SRC: &str = r#"#version 330 core
in vec2 v_uv;
out vec4 frag_color;
uniform sampler2D u_texture;
void main() {
    frag_color = texture(u_texture, v_uv);
}
"#;

// ---------------------------------------------------------------------------
// VideoUnderlay
// ---------------------------------------------------------------------------

pub struct VideoUnderlay {
    gl: glow::Context,
    /// The FBO we render the video into.
    fbo: glow::NativeFramebuffer,
    /// Color attachment texture (RGBA8).
    texture: glow::NativeTexture,
    /// Fullscreen-quad shader program.
    program: glow::NativeProgram,
    /// Dummy VAO required for attribute-less draws on core profile.
    vao: glow::NativeVertexArray,
    /// libmpv render context.
    render_ctx: *mut mpv_render_context,
    /// Heap-allocated flag; pointer passed to the update callback.
    /// Box ensures the address is stable.
    needs_redraw: Box<AtomicBool>,
    /// Heap-allocated proc-address context; pointer passed to libmpv.
    _proc_addr_ctx: Box<ProcAddrCtx>,
    /// Last rendered size (used to rebuild FBO on resize).
    width: u32,
    height: u32,
}

// SAFETY: `VideoUnderlay` contains raw pointers (`*mut mpv_render_context`) and a
// `glow::Context` (which wraps raw GL function pointers) — neither is `Send`/`Sync`
// by default. The safety invariant is enforced by the caller at the architectural level:
// all methods (`new`, `render`, `draw_underlay`, `needs_redraw`, `drop`) MUST be called
// exclusively from the Slint GL thread (the thread on which the OpenGL context is current).
// No method is ever called concurrently — Slint's rendering pipeline is single-threaded
// with respect to GL operations. The `needs_redraw` `AtomicBool` is the only field
// accessed from a different thread (the mpv update callback), and it uses `Acquire`/`Release`
// ordering to ensure visibility without data races. Ownership of the raw pointers is
// exclusive: libmpv does not retain a reference to `mpv_render_context` after
// `mpv_render_context_free` is called in `Drop`, which runs on the GL thread.
unsafe impl Send for VideoUnderlay {}
unsafe impl Sync for VideoUnderlay {}

impl VideoUnderlay {
    /// Create the render context and allocate the FBO.
    ///
    /// # Safety
    /// - `mpv_handle` must be a valid, non-null `mpv_handle` pointer.
    /// - The GL context must be current on the calling thread.
    /// - `get_proc_address` must return valid GL function pointers for the current context.
    pub unsafe fn new(
        mpv_handle: *mut mpv_handle,
        get_proc_address: &dyn Fn(&CStr) -> *const c_void,
        width: u32,
        height: u32,
    ) -> Result<Self, String> {
        unsafe {
            // --- Build glow context ---
            let gl = glow::Context::from_loader_function(|name| {
                let cname = CString::new(name).unwrap_or_default();
                get_proc_address(cname.as_c_str())
            });

            // --- Create FBO + texture ---
            let (fbo, texture) = Self::create_fbo(&gl, width, height)?;

            // --- Compile fullscreen-quad shader ---
            let (program, vao) = Self::create_shader_program(&gl)?;

            // --- Set up proc-address context for libmpv ---
            // SAFETY: The caller guarantees `get_proc_address` remains valid for the
            // lifetime of this VideoUnderlay. We transmute to erase the borrow lifetime
            // so the closure can be stored in a Box<dyn Fn>. The raw pointer is never
            // dereferenced after VideoUnderlay is dropped (render context is freed first).
            let gpa_static: &'static dyn Fn(&CStr) -> *const c_void =
                std::mem::transmute::<
                    &dyn Fn(&CStr) -> *const c_void,
                    &'static dyn Fn(&CStr) -> *const c_void,
                >(get_proc_address);

            let proc_addr_ctx = Box::new(ProcAddrCtx {
                func: Box::new(move |name: &CStr| -> *const c_void { gpa_static(name) }),
            });

            let proc_addr_ctx_ptr = proc_addr_ctx.as_ref() as *const ProcAddrCtx as *mut c_void;

            let mut opengl_init_params = mpv_opengl_init_params {
                get_proc_address: Some(get_proc_address_trampoline),
                get_proc_address_ctx: proc_addr_ctx_ptr,
                extra_exts: std::ptr::null(),
            };

            // --- Build param array for mpv_render_context_create ---
            let api_type_str = MPV_RENDER_API_TYPE_OPENGL.as_ptr() as *const std::os::raw::c_char;
            let mut params = [
                mpv_render_param {
                    type_: PARAM_API_TYPE,
                    data: api_type_str as *mut c_void,
                },
                mpv_render_param {
                    type_: PARAM_OPENGL_INIT_PARAMS,
                    data: &mut opengl_init_params as *mut mpv_opengl_init_params as *mut c_void,
                },
                // Terminator
                mpv_render_param {
                    type_: PARAM_INVALID,
                    data: std::ptr::null_mut(),
                },
            ];

            // --- Create render context ---
            let mut render_ctx: *mut mpv_render_context = std::ptr::null_mut();
            let err = mpv_render_context_create(&mut render_ctx, mpv_handle, params.as_mut_ptr());
            if err < 0 {
                return Err(format!(
                    "mpv_render_context_create failed: error code {err}"
                ));
            }
            if render_ctx.is_null() {
                return Err("mpv_render_context_create returned null context".to_string());
            }

            // --- Set update callback ---
            let needs_redraw = Box::new(AtomicBool::new(false));
            let needs_redraw_ptr = needs_redraw.as_ref() as *const AtomicBool as *mut c_void;
            mpv_render_context_set_update_callback(
                render_ctx,
                Some(update_callback),
                needs_redraw_ptr,
            );

            Ok(Self {
                gl,
                fbo,
                texture,
                program,
                vao,
                render_ctx,
                needs_redraw,
                _proc_addr_ctx: proc_addr_ctx,
                width,
                height,
            })
        }
    }

    /// Render mpv's current frame into the FBO.
    ///
    /// Call this from Slint's `BeforeRendering` callback (GL thread, context current).
    /// If `width`/`height` changed since last call, the FBO is recreated.
    pub fn render(&mut self, width: i32, height: i32) {
        let w = width.max(1) as u32;
        let h = height.max(1) as u32;

        // Rebuild FBO if size changed.
        if w != self.width || h != self.height {
            unsafe {
                if let Ok((new_fbo, new_tex)) = Self::create_fbo(&self.gl, w, h) {
                    self.gl.delete_framebuffer(self.fbo);
                    self.gl.delete_texture(self.texture);
                    self.fbo = new_fbo;
                    self.texture = new_tex;
                    self.width = w;
                    self.height = h;
                }
            }
        }

        // Clear the redraw flag before rendering.
        self.needs_redraw.store(false, Ordering::Release);

        // NativeFramebuffer(NonZeroU32) — extract the raw GL name.
        let fbo_id = self.fbo.0.get() as i32;

        let mut fbo_params = mpv_opengl_fbo {
            fbo: fbo_id,
            w: width,
            h: height,
            internal_format: 0, // let mpv decide
        };

        let mut flip_y: i32 = 1; // flip so top-left origin matches Slint

        let mut params = [
            mpv_render_param {
                type_: PARAM_OPENGL_FBO,
                data: &mut fbo_params as *mut mpv_opengl_fbo as *mut c_void,
            },
            mpv_render_param {
                type_: PARAM_FLIP_Y,
                data: &mut flip_y as *mut i32 as *mut c_void,
            },
            mpv_render_param {
                type_: PARAM_INVALID,
                data: std::ptr::null_mut(),
            },
        ];

        unsafe {
            mpv_render_context_render(self.render_ctx, params.as_mut_ptr());
        }
    }

    /// Draw the FBO texture as a fullscreen underlay quad.
    ///
    /// Call this immediately after `render()`, before Slint composites its own UI.
    pub fn draw_underlay(&self) {
        unsafe {
            // Save state
            let prev_program = self.gl.get_parameter_i32(glow::CURRENT_PROGRAM) as u32;

            self.gl.use_program(Some(self.program));
            self.gl.bind_vertex_array(Some(self.vao));

            // Bind our video texture to unit 0
            self.gl.active_texture(glow::TEXTURE0);
            self.gl.bind_texture(glow::TEXTURE_2D, Some(self.texture));

            let loc = self.gl.get_uniform_location(self.program, "u_texture");
            self.gl.uniform_1_i32(loc.as_ref(), 0);

            // Disable depth test for the underlay quad
            let depth_test_was_on = self.gl.is_enabled(glow::DEPTH_TEST);
            self.gl.disable(glow::DEPTH_TEST);

            self.gl.draw_arrays(glow::TRIANGLES, 0, 3);

            if depth_test_was_on {
                self.gl.enable(glow::DEPTH_TEST);
            }

            // Restore state
            self.gl.bind_texture(glow::TEXTURE_2D, None);
            self.gl.bind_vertex_array(None);
            self.gl.use_program(if prev_program != 0 {
                Some(glow::NativeProgram(
                    std::num::NonZeroU32::new(prev_program).unwrap(),
                ))
            } else {
                None
            });
        }
    }

    /// Returns `true` if mpv has signalled a new frame is ready.
    pub fn needs_redraw(&self) -> bool {
        if self.needs_redraw.load(Ordering::Acquire) {
            unsafe {
                let flags = mpv_render_context_update(self.render_ctx);
                return flags & (UPDATE_FRAME as u64) != 0;
            }
        }
        false
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    unsafe fn create_fbo(
        gl: &glow::Context,
        width: u32,
        height: u32,
    ) -> Result<(glow::NativeFramebuffer, glow::NativeTexture), String> {
        unsafe {
            // Create RGBA8 texture
            let texture = gl
                .create_texture()
                .map_err(|e| format!("create_texture: {e}"))?;
            gl.bind_texture(glow::TEXTURE_2D, Some(texture));
            gl.tex_image_2d(
                glow::TEXTURE_2D,
                0,
                glow::RGBA8 as i32,
                width as i32,
                height as i32,
                0,
                glow::RGBA,
                glow::UNSIGNED_BYTE,
                glow::PixelUnpackData::Slice(None),
            );
            gl.tex_parameter_i32(
                glow::TEXTURE_2D,
                glow::TEXTURE_MIN_FILTER,
                glow::LINEAR as i32,
            );
            gl.tex_parameter_i32(
                glow::TEXTURE_2D,
                glow::TEXTURE_MAG_FILTER,
                glow::LINEAR as i32,
            );
            gl.tex_parameter_i32(
                glow::TEXTURE_2D,
                glow::TEXTURE_WRAP_S,
                glow::CLAMP_TO_EDGE as i32,
            );
            gl.tex_parameter_i32(
                glow::TEXTURE_2D,
                glow::TEXTURE_WRAP_T,
                glow::CLAMP_TO_EDGE as i32,
            );
            gl.bind_texture(glow::TEXTURE_2D, None);

            // Create FBO
            let fbo = gl
                .create_framebuffer()
                .map_err(|e| format!("create_framebuffer: {e}"))?;
            gl.bind_framebuffer(glow::FRAMEBUFFER, Some(fbo));
            gl.framebuffer_texture_2d(
                glow::FRAMEBUFFER,
                glow::COLOR_ATTACHMENT0,
                glow::TEXTURE_2D,
                Some(texture),
                0,
            );

            let status = gl.check_framebuffer_status(glow::FRAMEBUFFER);
            gl.bind_framebuffer(glow::FRAMEBUFFER, None);

            if status != glow::FRAMEBUFFER_COMPLETE {
                gl.delete_texture(texture);
                gl.delete_framebuffer(fbo);
                return Err(format!("FBO incomplete: status 0x{status:x}"));
            }

            Ok((fbo, texture))
        }
    }

    unsafe fn create_shader_program(
        gl: &glow::Context,
    ) -> Result<(glow::NativeProgram, glow::NativeVertexArray), String> {
        unsafe {
            let vert = gl
                .create_shader(glow::VERTEX_SHADER)
                .map_err(|e| format!("create vertex shader: {e}"))?;
            gl.shader_source(vert, QUAD_VERT_SRC);
            gl.compile_shader(vert);
            if !gl.get_shader_compile_status(vert) {
                let log = gl.get_shader_info_log(vert);
                gl.delete_shader(vert);
                return Err(format!("vertex shader compile error: {log}"));
            }

            let frag = gl
                .create_shader(glow::FRAGMENT_SHADER)
                .map_err(|e| format!("create fragment shader: {e}"))?;
            gl.shader_source(frag, QUAD_FRAG_SRC);
            gl.compile_shader(frag);
            if !gl.get_shader_compile_status(frag) {
                let log = gl.get_shader_info_log(frag);
                gl.delete_shader(vert);
                gl.delete_shader(frag);
                return Err(format!("fragment shader compile error: {log}"));
            }

            let program = gl
                .create_program()
                .map_err(|e| format!("create program: {e}"))?;
            gl.attach_shader(program, vert);
            gl.attach_shader(program, frag);
            gl.link_program(program);
            gl.delete_shader(vert);
            gl.delete_shader(frag);

            if !gl.get_program_link_status(program) {
                let log = gl.get_program_info_log(program);
                gl.delete_program(program);
                return Err(format!("shader link error: {log}"));
            }

            // Core-profile VAO required for attribute-less draw
            let vao = gl
                .create_vertex_array()
                .map_err(|e| format!("create_vertex_array: {e}"))?;

            Ok((program, vao))
        }
    }
}

impl Drop for VideoUnderlay {
    fn drop(&mut self) {
        unsafe {
            // Free the render context first (stops mpv from calling the update callback).
            if !self.render_ctx.is_null() {
                mpv_render_context_free(self.render_ctx);
                self.render_ctx = std::ptr::null_mut();
            }
            // Free GL resources (context must still be current).
            self.gl.delete_framebuffer(self.fbo);
            self.gl.delete_texture(self.texture);
            self.gl.delete_program(self.program);
            self.gl.delete_vertex_array(self.vao);
        }
    }
}
