// FFI bindings for OpenVINO C API
// These would normally be generated with bindgen

use std::os::raw::{c_char, c_void};

#[link(name = "openvino_c")]
extern "C" {
    pub fn ov_core_create() -> *mut c_void;
    pub fn ov_core_free(core: *mut c_void);
    
    pub fn ov_core_get_available_devices(core: *mut c_void) -> *const c_char;
    pub fn ov_core_read_model(core: *mut c_void, model_path: *const c_char) -> *mut c_void;
    pub fn ov_core_set_property(core: *mut c_void, key: *const c_char, value: *const c_char);
    
    pub fn ov_compile_model(
        core: *mut c_void,
        model: *mut c_void,
        device_name: *const c_char,
    ) -> *mut c_void;
    
    pub fn ov_compiled_model_free(compiled_model: *mut c_void);
    pub fn ov_compiled_model_create_infer_request(compiled_model: *mut c_void) -> *mut c_void;
    
    pub fn ov_infer_request_free(infer_request: *mut c_void);
    pub fn ov_infer_request_set_input_tensor(infer_request: *mut c_void, tensor: *mut c_void);
    pub fn ov_infer_request_get_output_tensor(infer_request: *mut c_void) -> *mut c_void;
    pub fn ov_infer_request_infer(infer_request: *mut c_void);
    
    pub fn ov_tensor_create_from_host_ptr(data: *const c_void, byte_size: usize) -> *mut c_void;
    pub fn ov_tensor_free(tensor: *mut c_void);
    pub fn ov_tensor_data(tensor: *mut c_void, data: *mut c_void);
    pub fn ov_tensor_get_byte_size(tensor: *mut c_void) -> usize;
}