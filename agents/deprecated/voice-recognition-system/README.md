# Voice Recognition System - Intel Core Ultra Optimized

A sophisticated voice recognition system that leverages the unique dual-accelerator architecture of Intel Core Ultra (Meteor Lake) processors, featuring both GNA (Gaussian Neural Accelerator) and NPU (Neural Processing Unit) for optimal performance and power efficiency.

## 🎯 Key Features

### Dual Accelerator Optimization
- **GNA (Gaussian Neural Accelerator)**: Handles real-time audio processing, voice biometrics, and acoustic models with minimal power consumption
- **NPU (Neural Processing Unit)**: Processes complex language models, deep speaker embeddings, and advanced AI tasks
- **Intelligent Task Routing**: Automatically distributes workloads between GNA and NPU for maximum efficiency

### Voice Biometrics & Personalization
- **Speaker Identification**: Automatically recognizes enrolled users by voice
- **Voice Profiles**: Maintains detailed biometric profiles including pitch, speaking rate, and voice quality metrics
- **Continuous Adaptation**: Learns from each interaction to improve recognition accuracy
- **Anti-Spoofing**: Liveness detection to prevent replay attacks

### Self-Improvement Engine
- **Automatic Learning**: Learns from corrections to improve accuracy over time
- **Personal Language Models**: Builds user-specific language models for better recognition
- **Error Pattern Analysis**: Identifies and corrects common recognition errors
- **Pronunciation Variants**: Adapts to individual pronunciation patterns

### Accuracy-First Design
- **Quality Over Speed**: Prioritizes transcription accuracy over latency
- **Multi-Model Verification**: Uses both acoustic and language models for validation
- **Confidence Scoring**: Provides confidence metrics for all transcriptions
- **Alternative Suggestions**: Offers alternative transcriptions when confidence is low

## 🚀 Quick Start

### Prerequisites
- Intel Core Ultra (Meteor Lake) processor with GNA and NPU
- Python 3.8 or higher
- OpenVINO toolkit 2023.0+
- 16GB RAM recommended

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd voice-recognition-system

# Install dependencies
pip install -r requirements.txt

# Download OpenVINO models (optional)
python scripts/download_models.py
```

### Basic Usage

```bash
# Start real-time recognition
python main.py

# Enroll a new user
python main.py --enroll "John Doe" --audio-files sample1.wav sample2.wav sample3.wav

# Transcribe a file
python main.py --transcribe audio_file.wav

# Run with custom configuration
python main.py --config config.json

# Save session data
python main.py --save-session ./sessions/session_001
```

## 📊 System Architecture

```
voice-recognition-system/
├── core/
│   └── accelerator_manager.py    # GNA/NPU coordination
├── biometrics/
│   └── voice_identity.py         # Speaker recognition
├── transcription/
│   └── realtime_asr.py          # Speech-to-text engine
├── training/
│   └── self_improvement.py       # Learning system
├── data/
│   ├── user_profiles/            # Voice profiles
│   ├── training_sets/            # Adaptation data
│   └── corrections.db            # Correction history
└── main.py                       # Main application
```

## 🔧 Configuration

Create a `config.json` file to customize the system:

```json
{
  "language": "en",
  "accelerator": {
    "gna_config": {
      "GNA_DEVICE_MODE": "GNA_HW",
      "GNA_PRECISION": "I16",
      "GNA_SCALE_FACTOR": "2048.0"
    },
    "npu_config": {
      "PERFORMANCE_HINT": "THROUGHPUT",
      "CACHE_DIR": "~/.cache/openvino_npu"
    }
  },
  "audio": {
    "sample_rate": 16000,
    "chunk_duration": 0.5,
    "energy_threshold": 0.01
  },
  "recognition": {
    "identification_threshold": 0.75,
    "verification_threshold": 0.85,
    "pause_threshold": 0.8
  }
}
```

## 💡 Usage Examples

### Enrolling Your Voice

```python
from voice_recognition_system import VoiceRecognitionSystem

system = VoiceRecognitionSystem()

# Record or load audio samples (minimum 3)
audio_samples = [
    load_audio("recording1.wav"),
    load_audio("recording2.wav"),
    load_audio("recording3.wav")
]

# Enroll user
profile = system.biometrics.enroll_user(
    name="Your Name",
    audio_samples=audio_samples
)

print(f"Enrolled with ID: {profile.user_id}")
```

### Real-Time Transcription with Speaker ID

```python
# Setup callbacks
def on_transcription(result):
    if result.speaker_id:
        speaker = system.biometrics.profiles[result.speaker_id].name
        print(f"[{speaker}] {result.text}")
    else:
        print(f"[Unknown] {result.text}")

system.asr.on_final_result = on_transcription

# Start recognition
system.start_recognition()
```

### Making Corrections for Learning

```python
# Correct a transcription
system.correct_transcription(
    original="The quick brown fox",
    corrected="The quick brown fox jumps"
)

# System learns from correction and improves future recognition
```

## 🎯 Optimization Tips

### For Maximum Accuracy
1. **Enrollment**: Provide diverse voice samples covering different speaking styles
2. **Environment**: Use in quiet environment or calibrate noise threshold
3. **Corrections**: Consistently correct errors to improve personal model
4. **Updates**: Let the system adapt over multiple sessions

### For Power Efficiency
1. **GNA Mode**: Keep acoustic models on GNA for continuous low-power operation
2. **NPU Batching**: Process language model corrections in batches
3. **Sleep States**: System automatically manages accelerator sleep states

### For Your Hardware
Since you have both GNA and NPU:
- Audio processing stays on GNA (always-on, minimal battery impact)
- Complex AI runs on NPU (higher performance when needed)
- CPU remains free for other tasks

## 📈 Performance Metrics

The system tracks:
- **Recognition Accuracy**: Confidence scores and error rates
- **Power Efficiency**: mWh saved using accelerators vs CPU
- **Adaptation Progress**: Improvement over time
- **Speaker Analytics**: Time per speaker, switch frequency
- **Accelerator Usage**: GNA vs NPU utilization

## 🔒 Privacy & Security

- **Local Processing**: All voice processing happens on-device
- **Encrypted Profiles**: Voice profiles are stored securely
- **Liveness Detection**: Anti-spoofing measures prevent replay attacks
- **User Control**: Easy profile deletion and data export

## 🐛 Troubleshooting

### GNA/NPU Not Detected
```bash
# Check available devices
python -c "import openvino as ov; print(ov.Core().available_devices)"
```

### Audio Issues
```bash
# List audio devices
python -c "import sounddevice as sd; print(sd.query_devices())"
```

### Performance Issues
- Ensure OpenVINO is properly installed
- Check that models are compiled for correct target (GNA 3.0 for Meteor Lake)
- Verify audio sample rate matches configuration (16kHz recommended)

## 📝 Advanced Features

### Custom Model Integration
```python
# Load your own acoustic model on GNA
system.accelerator.load_model(
    model_path="path/to/model.xml",
    model_name="custom_acoustic",
    accelerator="GNA",
    model_type="acoustic"
)
```

### Export Personal Model
```python
# Export your personalized language model
system.improvement.export_personal_model(
    speaker_id="your_id",
    export_path="my_voice_model.json"
)
```

### Benchmark Dual Acceleration
```bash
# Compare GNA vs NPU vs CPU performance
python main.py --benchmark
```

## 🤝 Contributing

This system is designed for personal use and optimization. Feel free to:
- Add new models and improve accuracy
- Enhance the self-learning algorithms
- Optimize for specific use cases
- Share performance benchmarks

## 📄 License

MIT License - Feel free to modify for your personal use

## 🙏 Acknowledgments

- Intel for the innovative GNA/NPU dual-accelerator architecture
- OpenVINO team for the excellent inference toolkit
- The speech recognition research community

---

**Note**: This system is specifically optimized for Intel Core Ultra (Meteor Lake) processors. While it will work on other systems, the dual-accelerator features are unique to this hardware generation.