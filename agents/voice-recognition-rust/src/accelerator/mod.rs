use anyhow::{Result, anyhow};
use once_cell::sync::Lazy;
use parking_lot::RwLock;
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};
use std::ptr;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use tracing::{debug, info, warn};

mod openvino_sys;
use openvino_sys::*;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum AcceleratorType {
    GNA,
    NPU,
    CPU,
}

#[derive(Debug)]
pub struct AcceleratorMetrics {
    gna_inferences: AtomicUsize,
    npu_inferences: AtomicUsize,
    gna_total_ns: AtomicU64,
    npu_total_ns: AtomicU64,
    power_saved_mwh: AtomicU64,
}

pub struct CompiledModel {
    handle: *mut c_void,
    device: AcceleratorType,
}

unsafe impl Send for CompiledModel {}
unsafe impl Sync for CompiledModel {}

pub struct DualAcceleratorManager {
    core: *mut c_void,
    gna_available: bool,
    npu_available: bool,
    models: Arc<RwLock<HashMap<String, Arc<CompiledModel>>>>,
    metrics: Arc<AcceleratorMetrics>,
}

impl DualAcceleratorManager {
    pub fn new() -> Result<Self> {
        unsafe {
            // Initialize OpenVINO core
            let core = ov_core_create();
            if core.is_null() {
                return Err(anyhow!("Failed to create OpenVINO core"));
            }
            
            // Check available devices
            let devices = Self::get_available_devices(core)?;
            let gna_available = devices.contains(&"GNA".to_string());
            let npu_available = devices.contains(&"NPU".to_string());
            
            info!("Available devices: {:?}", devices);
            
            Ok(Self {
                core,
                gna_available,
                npu_available,
                models: Arc::new(RwLock::new(HashMap::new())),
                metrics: Arc::new(AcceleratorMetrics {
                    gna_inferences: AtomicUsize::new(0),
                    npu_inferences: AtomicUsize::new(0),
                    gna_total_ns: AtomicU64::new(0),
                    npu_total_ns: AtomicU64::new(0),
                    power_saved_mwh: AtomicU64::new(0),
                }),
            })
        }
    }
    
    pub fn has_gna(&self) -> bool {
        self.gna_available
    }
    
    pub fn has_npu(&self) -> bool {
        self.npu_available
    }
    
    unsafe fn get_available_devices(core: *mut c_void) -> Result<Vec<String>> {
        let devices_ptr = ov_core_get_available_devices(core);
        if devices_ptr.is_null() {
            return Ok(vec![]);
        }
        
        let devices_str = CStr::from_ptr(devices_ptr).to_string_lossy();
        Ok(devices_str.split(',').map(|s| s.to_string()).collect())
    }
    
    pub fn load_model(
        &self,
        model_path: &str,
        model_name: &str,
        device: AcceleratorType,
    ) -> Result<()> {
        unsafe {
            let model_path_c = CString::new(model_path)?;
            let model = ov_core_read_model(self.core, model_path_c.as_ptr());
            
            if model.is_null() {
                return Err(anyhow!("Failed to read model: {}", model_path));
            }
            
            let device_str = match device {
                AcceleratorType::GNA if self.gna_available => "GNA",
                AcceleratorType::NPU if self.npu_available => "NPU",
                _ => "CPU",
            };
            
            let device_c = CString::new(device_str)?;
            
            // Configure device-specific optimizations
            if device == AcceleratorType::GNA {
                self.configure_gna_optimizations()?;
            } else if device == AcceleratorType::NPU {
                self.configure_npu_optimizations()?;
            }
            
            let compiled = ov_compile_model(self.core, model, device_c.as_ptr());
            
            if compiled.is_null() {
                return Err(anyhow!("Failed to compile model for {}", device_str));
            }
            
            let compiled_model = Arc::new(CompiledModel {
                handle: compiled,
                device,
            });
            
            self.models.write().insert(model_name.to_string(), compiled_model);
            
            info!("Model '{}' loaded on {:?}", model_name, device);
            Ok(())
        }
    }
    
    fn configure_gna_optimizations(&self) -> Result<()> {
        unsafe {
            // GNA 3.0 specific optimizations for Meteor Lake
            let configs = vec![
                ("GNA_DEVICE_MODE", "GNA_HW"),
                ("GNA_PRECISION", "I16"),
                ("GNA_PERFORMANCE_HINT", "LATENCY"),
                ("GNA_COMPILE_TARGET", "GNA_TARGET_3_0"),
                ("GNA_SCALE_FACTOR", "2048.0"),
            ];
            
            for (key, value) in configs {
                let key_c = CString::new(key)?;
                let value_c = CString::new(value)?;
                ov_core_set_property(self.core, key_c.as_ptr(), value_c.as_ptr());
            }
        }
        Ok(())
    }
    
    fn configure_npu_optimizations(&self) -> Result<()> {
        unsafe {
            let configs = vec![
                ("PERFORMANCE_HINT", "THROUGHPUT"),
                ("ENABLE_PROFILING", "NO"),
            ];
            
            for (key, value) in configs {
                let key_c = CString::new(key)?;
                let value_c = CString::new(value)?;
                ov_core_set_property(self.core, key_c.as_ptr(), value_c.as_ptr());
            }
        }
        Ok(())
    }
    
    pub async fn infer(&self, model_name: &str, input: &[f32]) -> Result<Vec<f32>> {
        let start = std::time::Instant::now();
        
        let models = self.models.read();
        let model = models.get(model_name)
            .ok_or_else(|| anyhow!("Model '{}' not loaded", model_name))?;
        
        let result = unsafe {
            let infer_request = ov_compiled_model_create_infer_request(model.handle);
            if infer_request.is_null() {
                return Err(anyhow!("Failed to create inference request"));
            }
            
            // Set input tensor
            let input_tensor = ov_tensor_create_from_host_ptr(
                input.as_ptr() as *const c_void,
                input.len() * std::mem::size_of::<f32>(),
            );
            
            ov_infer_request_set_input_tensor(infer_request, input_tensor);
            
            // Run inference
            ov_infer_request_infer(infer_request);
            
            // Get output
            let output_tensor = ov_infer_request_get_output_tensor(infer_request);
            let output_size = ov_tensor_get_byte_size(output_tensor) / std::mem::size_of::<f32>();
            
            let mut output = vec![0.0f32; output_size];
            ov_tensor_data(output_tensor, output.as_mut_ptr() as *mut c_void);
            
            // Cleanup
            ov_tensor_free(input_tensor);
            ov_tensor_free(output_tensor);
            ov_infer_request_free(infer_request);
            
            output
        };
        
        // Update metrics
        let duration_ns = start.elapsed().as_nanos() as u64;
        
        match model.device {
            AcceleratorType::GNA => {
                self.metrics.gna_inferences.fetch_add(1, Ordering::Relaxed);
                self.metrics.gna_total_ns.fetch_add(duration_ns, Ordering::Relaxed);
                // GNA uses ~6x less power than CPU
                let power_saved = duration_ns / 1_000_000 * 5; // Simplified calculation
                self.metrics.power_saved_mwh.fetch_add(power_saved, Ordering::Relaxed);
            }
            AcceleratorType::NPU => {
                self.metrics.npu_inferences.fetch_add(1, Ordering::Relaxed);
                self.metrics.npu_total_ns.fetch_add(duration_ns, Ordering::Relaxed);
                // NPU uses ~4x less power than CPU
                let power_saved = duration_ns / 1_000_000 * 3;
                self.metrics.power_saved_mwh.fetch_add(power_saved, Ordering::Relaxed);
            }
            _ => {}
        }
        
        Ok(result)
    }
    
    pub async fn parallel_infer(
        &self,
        gna_model: &str,
        npu_model: &str,
        gna_input: &[f32],
        npu_input: &[f32],
    ) -> Result<(Vec<f32>, Vec<f32>)> {
        // Run both inferences in parallel
        let gna_future = self.infer(gna_model, gna_input);
        let npu_future = self.infer(npu_model, npu_input);
        
        let (gna_result, npu_result) = tokio::join!(gna_future, npu_future);
        
        Ok((gna_result?, npu_result?))
    }
    
    pub fn get_metrics(&self) -> HashMap<String, f64> {
        let mut metrics = HashMap::new();
        
        let gna_count = self.metrics.gna_inferences.load(Ordering::Relaxed);
        let npu_count = self.metrics.npu_inferences.load(Ordering::Relaxed);
        let gna_ns = self.metrics.gna_total_ns.load(Ordering::Relaxed);
        let npu_ns = self.metrics.npu_total_ns.load(Ordering::Relaxed);
        
        metrics.insert("gna_inferences".to_string(), gna_count as f64);
        metrics.insert("npu_inferences".to_string(), npu_count as f64);
        
        if gna_count > 0 {
            metrics.insert("gna_avg_latency_ms".to_string(), 
                          (gna_ns as f64 / gna_count as f64) / 1_000_000.0);
        }
        
        if npu_count > 0 {
            metrics.insert("npu_avg_latency_ms".to_string(), 
                          (npu_ns as f64 / npu_count as f64) / 1_000_000.0);
        }
        
        metrics.insert("power_saved_mwh".to_string(), 
                      self.metrics.power_saved_mwh.load(Ordering::Relaxed) as f64);
        
        metrics
    }
}

impl Drop for DualAcceleratorManager {
    fn drop(&mut self) {
        unsafe {
            if !self.core.is_null() {
                ov_core_free(self.core);
            }
        }
    }
}

impl Drop for CompiledModel {
    fn drop(&mut self) {
        unsafe {
            if !self.handle.is_null() {
                ov_compiled_model_free(self.handle);
            }
        }
    }
}