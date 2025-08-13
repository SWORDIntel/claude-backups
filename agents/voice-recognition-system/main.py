#!/usr/bin/env python3
"""
Main Voice Recognition System Application
Orchestrates all components for personalized, self-improving voice recognition
"""

import argparse
import sys
import os
import signal
import logging
from pathlib import Path
import json
import time
from typing import Optional, Dict, Any
import numpy as np

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from core.accelerator_manager import DualAcceleratorManager, AcceleratorType
from biometrics.voice_identity import VoiceBiometricSystem
from transcription.realtime_asr import RealtimeASR, TranscriptionResult
from training.self_improvement import SelfImprovementEngine

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class VoiceRecognitionSystem:
    """
    Main system orchestrator
    Coordinates all components for optimal voice processing
    """
    
    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize the voice recognition system
        
        Args:
            config_path: Path to configuration file
        """
        
        # Load configuration
        self.config = self._load_config(config_path)
        
        # Initialize components
        logger.info("Initializing Voice Recognition System...")
        
        # 1. Dual accelerator manager (GNA + NPU)
        self.accelerator = DualAcceleratorManager(self.config.get('accelerator', {}))
        
        # Optimize for voice processing
        self.accelerator.optimize_for_voice()
        
        # 2. Voice biometric system
        self.biometrics = VoiceBiometricSystem(
            accelerator_manager=self.accelerator,
            profile_dir=self.config.get('profile_dir', './data/user_profiles')
        )
        
        # 3. Real-time ASR
        self.asr = RealtimeASR(
            accelerator_manager=self.accelerator,
            biometric_system=self.biometrics,
            model_path=self.config.get('asr_model_path'),
            language=self.config.get('language', 'en')
        )
        
        # 4. Self-improvement engine
        self.improvement = SelfImprovementEngine(
            data_dir=self.config.get('training_dir', './data/training_sets'),
            db_path=self.config.get('corrections_db', './data/corrections.db')
        )
        
        # Setup callbacks
        self._setup_callbacks()
        
        # Session state
        self.current_speaker = None
        self.session_start = None
        self.is_running = False
        
        # Performance tracking
        self.session_metrics = {
            'total_duration': 0,
            'total_words': 0,
            'speaker_changes': 0,
            'corrections_made': 0,
            'accuracy_scores': []
        }
        
        logger.info("System initialized successfully")
        self._print_system_info()
    
    def _load_config(self, config_path: Optional[str]) -> Dict[str, Any]:
        """Load configuration from file or use defaults"""
        
        if config_path and Path(config_path).exists():
            with open(config_path, 'r') as f:
                config = json.load(f)
            logger.info(f"Loaded configuration from {config_path}")
        else:
            # Default configuration
            config = {
                'language': 'en',
                'profile_dir': './data/user_profiles',
                'training_dir': './data/training_sets',
                'corrections_db': './data/corrections.db',
                'asr_model_path': None,
                'accelerator': {
                    'gna_config': {
                        'GNA_DEVICE_MODE': 'GNA_HW',
                        'GNA_PRECISION': 'I16'
                    },
                    'npu_config': {
                        'PERFORMANCE_HINT': 'THROUGHPUT'
                    }
                },
                'audio': {
                    'sample_rate': 16000,
                    'chunk_duration': 0.5,
                    'energy_threshold': 0.01
                },
                'recognition': {
                    'identification_threshold': 0.75,
                    'verification_threshold': 0.85,
                    'pause_threshold': 0.8
                }
            }
        
        return config
    
    def _setup_callbacks(self):
        """Setup component callbacks"""
        
        # ASR callbacks
        self.asr.on_partial_result = self._on_partial_transcription
        self.asr.on_final_result = self._on_final_transcription
        self.asr.on_speaker_change = self._on_speaker_change
    
    def _print_system_info(self):
        """Print system information"""
        
        print("\n" + "="*60)
        print("Voice Recognition System - Intel Core Ultra Optimized")
        print("="*60)
        
        # Accelerator status
        if self.accelerator.has_gna and self.accelerator.has_npu:
            print("✓ Dual Accelerator Mode: GNA + NPU")
            print("  - GNA: Audio/Speech Processing (Low Power)")
            print("  - NPU: Complex AI/Language Models")
        elif self.accelerator.has_gna:
            print("⚠ GNA Only Mode (NPU not available)")
        elif self.accelerator.has_npu:
            print("⚠ NPU Only Mode (GNA not available)")
        else:
            print("⚠ CPU Fallback Mode (No accelerators)")
        
        # Profiles
        num_profiles = len(self.biometrics.profiles)
        print(f"\n✓ Voice Profiles: {num_profiles} enrolled")
        for user_id, profile in self.biometrics.profiles.items():
            print(f"  - {profile.name}: {profile.num_samples} samples")
        
        # Configuration
        print(f"\n✓ Language: {self.config.get('language', 'en')}")
        print(f"✓ Sample Rate: {self.asr.sample_rate} Hz")
        
        print("="*60 + "\n")
    
    def _on_partial_transcription(self, result: TranscriptionResult):
        """Handle partial transcription result"""
        
        # Display partial result
        if result.text:
            print(f"\r[Partial] {result.text}", end="", flush=True)
    
    def _on_final_transcription(self, result: TranscriptionResult):
        """Handle final transcription result"""
        
        # Clear partial line
        print("\r" + " " * 80 + "\r", end="")
        
        # Display final result with speaker
        speaker = ""
        if result.speaker_id and result.speaker_id in self.biometrics.profiles:
            speaker = f"[{self.biometrics.profiles[result.speaker_id].name}]"
        
        print(f"{speaker} {result.text}")
        
        # Update metrics
        self.session_metrics['total_words'] += len(result.text.split())
        self.session_metrics['accuracy_scores'].append(result.confidence)
        
        # Get improvement suggestions if available
        if result.speaker_id:
            suggestion = self.improvement.predict_correction(result.text, result.speaker_id)
            if suggestion and suggestion != result.text:
                print(f"  → Suggested: {suggestion}")
    
    def _on_speaker_change(self, speaker_id: str):
        """Handle speaker change"""
        
        if speaker_id != self.current_speaker:
            self.current_speaker = speaker_id
            self.session_metrics['speaker_changes'] += 1
            
            if speaker_id in self.biometrics.profiles:
                name = self.biometrics.profiles[speaker_id].name
                print(f"\n[Speaker changed to: {name}]\n")
    
    def start_recognition(self):
        """Start real-time recognition"""
        
        print("\nStarting real-time recognition...")
        print("Press Ctrl+C to stop\n")
        
        self.session_start = time.time()
        self.is_running = True
        
        # Start components
        self.improvement.start()
        self.asr.calibrate_noise()
        self.asr.start()
        
        # Setup signal handler
        signal.signal(signal.SIGINT, self._signal_handler)
        
        # Main loop
        try:
            while self.is_running:
                time.sleep(0.1)
                
                # Periodic metric display
                if int(time.time()) % 30 == 0:
                    self._display_metrics()
        
        except KeyboardInterrupt:
            pass
        finally:
            self.stop_recognition()
    
    def stop_recognition(self):
        """Stop recognition and cleanup"""
        
        print("\n\nStopping recognition...")
        
        self.is_running = False
        
        # Stop components
        self.asr.stop()
        self.improvement.stop()
        
        # Calculate session duration
        if self.session_start:
            self.session_metrics['total_duration'] = time.time() - self.session_start
        
        # Display final metrics
        self._display_final_report()
    
    def _signal_handler(self, signum, frame):
        """Handle interrupt signal"""
        self.is_running = False
    
    def _display_metrics(self):
        """Display current metrics"""
        
        metrics = self.accelerator.get_metrics()
        
        # Don't interrupt transcription display
        print(f"\n[Metrics] GNA: {metrics.get('gna_inferences', 0)} inferences, "
              f"NPU: {metrics.get('npu_inferences', 0)} inferences, "
              f"Power saved: {metrics.get('power_saved_mwh', 0):.1f} mWh")
    
    def _display_final_report(self):
        """Display session summary"""
        
        print("\n" + "="*60)
        print("Session Summary")
        print("="*60)
        
        # Duration
        duration = self.session_metrics['total_duration']
        if duration > 0:
            minutes = int(duration // 60)
            seconds = int(duration % 60)
            print(f"Duration: {minutes}m {seconds}s")
        
        # Transcription stats
        print(f"Words transcribed: {self.session_metrics['total_words']}")
        
        if self.session_metrics['accuracy_scores']:
            avg_confidence = np.mean(self.session_metrics['accuracy_scores'])
            print(f"Average confidence: {avg_confidence:.2%}")
        
        print(f"Speaker changes: {self.session_metrics['speaker_changes']}")
        
        # Accelerator usage
        accel_metrics = self.accelerator.get_metrics()
        print(f"\nAccelerator Usage:")
        print(f"  GNA inferences: {accel_metrics.get('gna_inferences', 0)}")
        print(f"  NPU inferences: {accel_metrics.get('npu_inferences', 0)}")
        
        if accel_metrics.get('gna_avg_latency'):
            print(f"  GNA avg latency: {accel_metrics['gna_avg_latency']*1000:.1f}ms")
        if accel_metrics.get('npu_avg_latency'):
            print(f"  NPU avg latency: {accel_metrics['npu_avg_latency']*1000:.1f}ms")
        
        print(f"  Power saved: ~{accel_metrics.get('power_saved_mwh', 0):.1f} mWh")
        
        # Improvement metrics
        improve_metrics = self.improvement.get_metrics()
        if improve_metrics['total_corrections'] > 0:
            print(f"\nLearning Progress:")
            print(f"  Total corrections: {improve_metrics['total_corrections']}")
            print(f"  Accuracy improvement: {improve_metrics['accuracy_improvement']:.1%}")
            
            # Common errors
            common_errors = self.improvement.get_common_errors(n=3)
            if common_errors:
                print(f"  Common errors:")
                for error, count in common_errors:
                    print(f"    - '{error}': {count} times")
        
        print("="*60)
    
    def enroll_user(self, name: str, audio_files: list):
        """Enroll a new user"""
        
        print(f"\nEnrolling user: {name}")
        
        # Load audio samples
        samples = []
        for audio_file in audio_files:
            # Load audio (placeholder - would use librosa)
            print(f"  Loading {audio_file}...")
            # audio, sr = librosa.load(audio_file, sr=16000)
            # samples.append(audio)
        
        if len(samples) >= 3:
            profile = self.biometrics.enroll_user(name, samples)
            print(f"✓ Successfully enrolled {name} (ID: {profile.user_id})")
        else:
            print("✗ Need at least 3 audio samples for enrollment")
    
    def correct_transcription(self, original: str, corrected: str):
        """Manually correct a transcription"""
        
        if self.current_speaker:
            self.improvement.add_correction(
                original=original,
                corrected=corrected,
                speaker_id=self.current_speaker,
                confidence=0.5
            )
            
            self.session_metrics['corrections_made'] += 1
            print(f"✓ Correction saved. Learning from your feedback...")
    
    def save_session(self, output_dir: str):
        """Save session data"""
        
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Save transcript
        self.asr.save_transcript(str(output_path / "transcript.json"), format="json")
        self.asr.save_transcript(str(output_path / "transcript.txt"), format="txt")
        
        # Save metrics
        metrics = {
            'session': self.session_metrics,
            'accelerator': self.accelerator.get_metrics(),
            'improvement': self.improvement.get_metrics()
        }
        
        with open(output_path / "metrics.json", 'w') as f:
            json.dump(metrics, f, indent=2)
        
        print(f"✓ Session saved to {output_path}")


def main():
    """Main entry point"""
    
    parser = argparse.ArgumentParser(
        description="Voice Recognition System - Intel Core Ultra Optimized"
    )
    
    parser.add_argument(
        '--config',
        type=str,
        help='Path to configuration file'
    )
    
    parser.add_argument(
        '--enroll',
        type=str,
        help='Enroll a new user (provide name)'
    )
    
    parser.add_argument(
        '--audio-files',
        nargs='+',
        help='Audio files for enrollment'
    )
    
    parser.add_argument(
        '--transcribe',
        type=str,
        help='Transcribe an audio file'
    )
    
    parser.add_argument(
        '--benchmark',
        action='store_true',
        help='Run benchmark on dual accelerators'
    )
    
    parser.add_argument(
        '--save-session',
        type=str,
        help='Directory to save session data'
    )
    
    args = parser.parse_args()
    
    # Initialize system
    system = VoiceRecognitionSystem(config_path=args.config)
    
    try:
        if args.enroll and args.audio_files:
            # Enrollment mode
            system.enroll_user(args.enroll, args.audio_files)
        
        elif args.transcribe:
            # File transcription mode
            print(f"Transcribing {args.transcribe}...")
            results = system.asr.transcribe_file(args.transcribe)
            for result in results:
                print(f"{result.text}")
        
        elif args.benchmark:
            # Benchmark mode
            print("Running dual accelerator benchmark...")
            # Would implement actual benchmark
            metrics = system.accelerator.benchmark_dual_acceleration(
                np.random.randn(16000 * 10)  # 10 seconds of audio
            )
            print(f"Benchmark results: {metrics}")
        
        else:
            # Real-time recognition mode
            system.start_recognition()
        
        # Save session if requested
        if args.save_session:
            system.save_session(args.save_session)
    
    except Exception as e:
        logger.error(f"System error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()