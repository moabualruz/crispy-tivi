//! Generic O(1) ring buffer (circular queue).

pub struct RingBuffer<T> {
    buf: Vec<Option<T>>,
    head: usize,
    len: usize,
    capacity: usize,
}

impl<T: Clone> RingBuffer<T> {
    pub fn new(capacity: usize) -> Self {
        assert!(capacity > 0, "RingBuffer capacity must be > 0");
        let mut buf = Vec::with_capacity(capacity);
        for _ in 0..capacity {
            buf.push(None);
        }
        Self {
            buf,
            head: 0,
            len: 0,
            capacity,
        }
    }

    /// Push a value. Panics if full.
    pub fn push(&mut self, value: T) {
        if self.is_full() {
            panic!("RingBuffer is full (capacity {})", self.capacity);
        }
        let tail = (self.head + self.len) % self.capacity;
        self.buf[tail] = Some(value);
        self.len += 1;
    }

    /// Remove and return the oldest element. Returns `None` if empty.
    pub fn pop_head(&mut self) -> Option<T> {
        if self.len == 0 {
            return None;
        }
        let val = self.buf[self.head].take();
        self.head = (self.head + 1) % self.capacity;
        self.len -= 1;
        val
    }

    /// Get a reference to element at logical position `idx` (0 = oldest).
    pub fn get(&self, idx: usize) -> Option<&T> {
        if idx >= self.len {
            return None;
        }
        let pos = (self.head + idx) % self.capacity;
        self.buf[pos].as_ref()
    }

    pub fn len(&self) -> usize {
        self.len
    }
    pub fn capacity(&self) -> usize {
        self.capacity
    }
    pub fn is_empty(&self) -> bool {
        self.len == 0
    }
    pub fn is_full(&self) -> bool {
        self.len == self.capacity
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_push_increments_len() {
        let mut rb = RingBuffer::new(4);
        assert_eq!(rb.len(), 0);
        rb.push(1u32);
        assert_eq!(rb.len(), 1);
        rb.push(2);
        assert_eq!(rb.len(), 2);
    }

    #[test]
    fn test_pop_returns_oldest_fifo() {
        let mut rb = RingBuffer::new(4);
        rb.push(10u32);
        rb.push(20);
        rb.push(30);
        assert_eq!(rb.pop_head(), Some(10));
        assert_eq!(rb.pop_head(), Some(20));
        assert_eq!(rb.pop_head(), Some(30));
        assert_eq!(rb.pop_head(), None);
    }

    #[test]
    fn test_wraps_correctly_after_full_cycle() {
        let mut rb = RingBuffer::new(3);
        rb.push(1u32);
        rb.push(2);
        rb.push(3);
        rb.pop_head(); // remove 1
        rb.push(4); // wraps into slot 0
        assert_eq!(rb.pop_head(), Some(2));
        assert_eq!(rb.pop_head(), Some(3));
        assert_eq!(rb.pop_head(), Some(4));
    }

    #[test]
    fn test_is_full_when_at_capacity() {
        let mut rb = RingBuffer::new(2);
        rb.push(1u32);
        rb.push(2);
        assert!(rb.is_full());
    }

    #[test]
    #[should_panic(expected = "RingBuffer is full")]
    fn test_push_beyond_capacity_panics() {
        let mut rb = RingBuffer::new(2);
        rb.push(1u32);
        rb.push(2);
        rb.push(3); // should panic
    }

    #[test]
    fn test_get_logical_index() {
        let mut rb = RingBuffer::new(4);
        rb.push(10u32);
        rb.push(20);
        rb.push(30);
        assert_eq!(rb.get(0), Some(&10));
        assert_eq!(rb.get(1), Some(&20));
        assert_eq!(rb.get(2), Some(&30));
        assert_eq!(rb.get(3), None);
    }

    #[test]
    #[should_panic(expected = "RingBuffer capacity must be > 0")]
    fn test_zero_capacity_panics() {
        // Covers lines 29-30: assert!(capacity > 0)
        let _rb: RingBuffer<u32> = RingBuffer::new(0);
    }

    #[test]
    fn test_get_out_of_bounds_returns_none() {
        // Additional coverage for get() bounds check
        let rb: RingBuffer<u32> = RingBuffer::new(4);
        assert_eq!(rb.get(0), None); // empty buffer
    }

    #[test]
    fn test_is_empty_initial() {
        let rb: RingBuffer<u32> = RingBuffer::new(4);
        assert!(rb.is_empty());
    }

    #[test]
    fn test_capacity_preserved() {
        let rb: RingBuffer<u32> = RingBuffer::new(8);
        assert_eq!(rb.capacity(), 8);
    }
}
