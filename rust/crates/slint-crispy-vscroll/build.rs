fn main() {
    // slint is always a dependency — compile .slint files unconditionally.
    slint_build::compile("ui/virtual-scroll-base.slint").expect("slint compilation failed");

    println!("cargo:rerun-if-changed=ui/scroll-primitives.slint");
    println!("cargo:rerun-if-changed=ui/virtual-scroll-base.slint");
    println!("cargo:rerun-if-changed=build.rs");
}
