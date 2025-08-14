"""
Voice Biometric System for Speaker Recognition and Personalization
Uses GNA for efficient voice fingerprinting and NPU for advanced analysis
"""

import numpy as np
from typing import Dict, List, Optional, Tuple, Any
import pickle
from pathlib import Path
import librosa
import soundfile as sf
from scipy.spatial.distance import cosine
from sklearn.mixture import GaussianMixture
import hashlib
import json
import logging
from datetime import datetime
from dataclasses import dataclass, asdict
import threading
import queue

logger = logging.getLogger(__name__)


@dataclass
class VoiceProfile:
    """Individual voice biometric profile"""
    user_id: str
    name: str
    created_at: datetime
    updated_at: datetime
    
    # Voice characteristics
    mfcc_mean: np.ndarray  # Mel-frequency cepstral coefficients
    mfcc_std: np.ndarray
    pitch_range: Tuple[float, float]  # Min, max fundamental frequency
    speaking_rate: float  # Words per minute average
    voice_quality: Dict[str, float]  # Jitter, shimmer, HNR
    
    # Embeddings
    speaker_embedding: np.ndarray  # Deep speaker embedding (512D)
    gmm_model: Optional[Any] = None  # Gaussian Mixture Model
    
    # Adaptation data
    num_samples: int = 0
    total_duration: float = 0.0  # Total audio duration in seconds
    confidence_threshold: float = 0.85
    false_accept_rate: float = 0.01
    
    # Personal speech patterns
    common_phrases: List[str] = None
    pronunciation_variants: Dict[str, List[str]] = None
    accent_markers: Dict[str, float] = None
    
    def to_dict(self) -> dict:
        """Serialize profile to dictionary"""
        data = asdict(self)
        # Convert numpy arrays to lists for JSON serialization
        data['mfcc_mean'] = self.mfcc_mean.tolist()
        data['mfcc_std'] = self.mfcc_std.tolist()
        data['speaker_embedding'] = self.speaker_embedding.tolist()
        data['created_at'] = self.created_at.isoformat()
        data['updated_at'] = self.updated_at.isoformat()
        data['gmm_model'] = None  # Will be saved separately
        return data
    
    @classmethod
    def from_dict(cls, data: dict) -> 'VoiceProfile':
        """Deserialize profile from dictionary"""
        data['mfcc_mean'] = np.array(data['mfcc_mean'])
        data['mfcc_std'] = np.array(data['mfcc_std'])
        data['speaker_embedding'] = np.array(data['speaker_embedding'])
        data['created_at'] = datetime.fromisoformat(data['created_at'])
        data['updated_at'] = datetime.fromisoformat(data['updated_at'])
        return cls(**data)


class VoiceBiometricSystem:
    """
    Advanced voice biometric system with self-improvement
    Runs on GNA for real-time identification, NPU for deep analysis
    """
    
    def __init__(self, accelerator_manager=None, profile_dir: str = "./data/user_profiles"):
        self.accelerator_manager = accelerator_manager
        self.profile_dir = Path(profile_dir)
        self.profile_dir.mkdir(parents=True, exist_ok=True)
        
        # Profile management
        self.profiles: Dict[str, VoiceProfile] = {}
        self.active_profile: Optional[VoiceProfile] = None
        
        # Feature extraction parameters
        self.sample_rate = 16000
        self.n_mfcc = 20
        self.n_mels = 128
        self.hop_length = 512
        self.n_fft = 2048
        
        # Recognition thresholds
        self.identification_threshold = 0.75
        self.verification_threshold = 0.85
        self.liveness_threshold = 0.90
        
        # Self-improvement queue
        self.adaptation_queue = queue.Queue()
        self.adaptation_thread = None
        
        self._load_profiles()
        self._init_models()
    
    def _load_profiles(self):
        """Load existing voice profiles from disk"""
        
        profile_files = self.profile_dir.glob("*.json")
        for pf in profile_files:
            try:
                with open(pf, 'r') as f:
                    data = json.load(f)
                profile = VoiceProfile.from_dict(data)
                
                # Load GMM model if exists
                gmm_path = pf.with_suffix('.gmm')
                if gmm_path.exists():
                    with open(gmm_path, 'rb') as f:
                        profile.gmm_model = pickle.load(f)
                
                self.profiles[profile.user_id] = profile
                logger.info(f"Loaded profile: {profile.name}")
                
            except Exception as e:
                logger.error(f"Failed to load profile {pf}: {e}")
    
    def _init_models(self):
        """Initialize biometric models on accelerators"""
        
        if self.accelerator_manager:
            # Load speaker verification model on GNA (small, efficient)
            # This would be a real model path in production
            try:
                self.accelerator_manager.load_model(
                    model_path="models/speaker_verification.xml",
                    model_name="speaker_verify",
                    accelerator="GNA",
                    model_type="biometric"
                )
            except:
                logger.warning("Speaker verification model not found, using CPU fallback")
            
            # Load deep speaker embedding model on NPU (larger, accurate)
            try:
                self.accelerator_manager.load_model(
                    model_path="models/deep_speaker_embedding.xml",
                    model_name="speaker_embed",
                    accelerator="NPU",
                    model_type="biometric"
                )
            except:
                logger.warning("Speaker embedding model not found, using CPU fallback")
    
    def extract_features(self, audio: np.ndarray, detailed: bool = False) -> Dict[str, Any]:
        """
        Extract voice biometric features from audio
        
        Args:
            audio: Audio signal array
            detailed: If True, extract all features for enrollment
        """
        
        features = {}
        
        # Basic MFCC features (always extracted)
        mfcc = librosa.feature.mfcc(
            y=audio, 
            sr=self.sample_rate,
            n_mfcc=self.n_mfcc,
            n_fft=self.n_fft,
            hop_length=self.hop_length
        )
        features['mfcc_mean'] = np.mean(mfcc, axis=1)
        features['mfcc_std'] = np.std(mfcc, axis=1)
        features['mfcc_delta'] = np.mean(librosa.feature.delta(mfcc), axis=1)
        
        if detailed:
            # Pitch/F0 extraction
            f0, voiced_flag, voiced_probs = librosa.pyin(
                audio,
                fmin=librosa.note_to_hz('C2'),
                fmax=librosa.note_to_hz('C7'),
                sr=self.sample_rate
            )
            f0_valid = f0[~np.isnan(f0)]
            if len(f0_valid) > 0:
                features['pitch_range'] = (float(np.min(f0_valid)), float(np.max(f0_valid)))
                features['pitch_mean'] = float(np.mean(f0_valid))
                features['pitch_std'] = float(np.std(f0_valid))
            else:
                features['pitch_range'] = (80.0, 250.0)  # Default range
                features['pitch_mean'] = 150.0
                features['pitch_std'] = 30.0
            
            # Voice quality metrics
            features['voice_quality'] = self._compute_voice_quality(audio)
            
            # Spectral features
            spectral_centroids = librosa.feature.spectral_centroid(y=audio, sr=self.sample_rate)
            features['spectral_centroid'] = float(np.mean(spectral_centroids))
            
            # Formant estimation (simplified)
            features['formants'] = self._estimate_formants(audio)
            
            # Speaking rate (requires transcription, placeholder)
            features['speaking_rate'] = 150.0  # Default WPM
        
        return features
    
    def _compute_voice_quality(self, audio: np.ndarray) -> Dict[str, float]:
        """Compute voice quality metrics (jitter, shimmer, HNR)"""
        
        quality = {}
        
        # Simplified jitter (pitch perturbation)
        f0, _, _ = librosa.pyin(audio, fmin=50, fmax=400, sr=self.sample_rate)
        f0_valid = f0[~np.isnan(f0)]
        
        if len(f0_valid) > 1:
            f0_diff = np.diff(f0_valid)
            quality['jitter'] = float(np.mean(np.abs(f0_diff)) / np.mean(f0_valid))
        else:
            quality['jitter'] = 0.01
        
        # Simplified shimmer (amplitude perturbation)
        amplitude_envelope = np.abs(librosa.stft(audio))
        amp_mean = np.mean(amplitude_envelope, axis=0)
        if len(amp_mean) > 1:
            amp_diff = np.diff(amp_mean)
            quality['shimmer'] = float(np.mean(np.abs(amp_diff)) / np.mean(amp_mean))
        else:
            quality['shimmer'] = 0.03
        
        # Harmonics-to-Noise Ratio (simplified)
        quality['hnr'] = self._compute_hnr(audio)
        
        return quality
    
    def _compute_hnr(self, audio: np.ndarray) -> float:
        """Compute Harmonics-to-Noise Ratio"""
        
        # Simplified HNR calculation
        autocorr = np.correlate(audio, audio, mode='same')
        autocorr = autocorr[len(autocorr)//2:]
        
        # Find first peak after zero lag
        peaks = librosa.util.peak_pick(autocorr, pre_max=3, post_max=3, 
                                      pre_avg=3, post_avg=5, delta=0.1, wait=10)
        
        if len(peaks) > 0:
            harmonic_peak = autocorr[peaks[0]]
            noise_floor = np.median(autocorr)
            if noise_floor > 0:
                hnr = 10 * np.log10(harmonic_peak / noise_floor)
                return float(np.clip(hnr, 0, 40))
        
        return 15.0  # Default HNR
    
    def _estimate_formants(self, audio: np.ndarray) -> List[float]:
        """Estimate formant frequencies (simplified)"""
        
        # LPC-based formant estimation (simplified)
        # In production, use proper formant tracking
        lpc_order = 12
        
        # Placeholder formant values (typical for adult male)
        # Real implementation would use LPC analysis
        return [700.0, 1500.0, 2500.0, 3500.0]  # F1-F4
    
    def create_embedding(self, audio: np.ndarray) -> np.ndarray:
        """
        Create deep speaker embedding using NPU
        """
        
        # Extract spectrogram for neural model
        mel_spec = librosa.feature.melspectrogram(
            y=audio,
            sr=self.sample_rate,
            n_mels=self.n_mels,
            n_fft=self.n_fft,
            hop_length=self.hop_length
        )
        mel_spec_db = librosa.power_to_db(mel_spec, ref=np.max)
        
        if self.accelerator_manager and "speaker_embed" in self.accelerator_manager.npu_models:
            # Use NPU for deep embedding
            embedding = self.accelerator_manager.infer("speaker_embed", mel_spec_db)
            return embedding[0]
        else:
            # Fallback: simple statistical embedding
            features = self.extract_features(audio, detailed=True)
            embedding = np.concatenate([
                features['mfcc_mean'],
                features['mfcc_std'],
                features['mfcc_delta'],
                [features.get('pitch_mean', 150.0)],
                [features.get('pitch_std', 30.0)],
                [features.get('spectral_centroid', 2000.0)]
            ])
            # Pad to 512 dimensions
            embedding = np.pad(embedding, (0, 512 - len(embedding)), mode='constant')
            return embedding
    
    def enroll_user(self, 
                    name: str,
                    audio_samples: List[np.ndarray],
                    user_id: Optional[str] = None) -> VoiceProfile:
        """
        Enroll a new user with voice samples
        
        Args:
            name: User's name
            audio_samples: List of voice recordings
            user_id: Optional custom user ID
        """
        
        if len(audio_samples) < 3:
            raise ValueError("At least 3 voice samples required for enrollment")
        
        # Generate user ID
        if not user_id:
            user_id = hashlib.sha256(name.encode() + str(datetime.now()).encode()).hexdigest()[:12]
        
        logger.info(f"Enrolling user: {name} (ID: {user_id})")
        
        # Extract features from all samples
        all_features = []
        all_embeddings = []
        total_duration = 0.0
        
        for audio in audio_samples:
            features = self.extract_features(audio, detailed=True)
            embedding = self.create_embedding(audio)
            
            all_features.append(features)
            all_embeddings.append(embedding)
            total_duration += len(audio) / self.sample_rate
        
        # Aggregate features
        mfcc_means = np.array([f['mfcc_mean'] for f in all_features])
        mfcc_stds = np.array([f['mfcc_std'] for f in all_features])
        
        # Create profile
        profile = VoiceProfile(
            user_id=user_id,
            name=name,
            created_at=datetime.now(),
            updated_at=datetime.now(),
            mfcc_mean=np.mean(mfcc_means, axis=0),
            mfcc_std=np.mean(mfcc_stds, axis=0),
            pitch_range=(
                min(f.get('pitch_range', (80, 250))[0] for f in all_features),
                max(f.get('pitch_range', (80, 250))[1] for f in all_features)
            ),
            speaking_rate=150.0,  # Default, will be updated with usage
            voice_quality=all_features[0].get('voice_quality', {}),
            speaker_embedding=np.mean(all_embeddings, axis=0),
            num_samples=len(audio_samples),
            total_duration=total_duration
        )
        
        # Train GMM for this speaker
        profile.gmm_model = self._train_gmm(all_features)
        
        # Save profile
        self.profiles[user_id] = profile
        self._save_profile(profile)
        
        logger.info(f"Successfully enrolled {name} with {len(audio_samples)} samples")
        
        return profile
    
    def _train_gmm(self, features: List[Dict]) -> GaussianMixture:
        """Train a Gaussian Mixture Model for speaker modeling"""
        
        # Combine all features into matrix
        feature_matrix = []
        for f in features:
            vec = np.concatenate([
                f['mfcc_mean'],
                f['mfcc_std'],
                f.get('mfcc_delta', np.zeros(self.n_mfcc))
            ])
            feature_matrix.append(vec)
        
        feature_matrix = np.array(feature_matrix)
        
        # Train GMM
        gmm = GaussianMixture(
            n_components=min(16, len(features)),
            covariance_type='diag',
            max_iter=200,
            random_state=42
        )
        gmm.fit(feature_matrix)
        
        return gmm
    
    def identify_speaker(self, audio: np.ndarray) -> Tuple[Optional[str], float]:
        """
        Identify speaker from enrolled profiles
        Uses GNA for fast identification
        
        Returns:
            (user_id, confidence) or (None, 0.0) if not recognized
        """
        
        if not self.profiles:
            return None, 0.0
        
        # Extract features
        features = self.extract_features(audio, detailed=False)
        embedding = self.create_embedding(audio)
        
        best_match = None
        best_score = -float('inf')
        
        # Fast matching using GNA
        if self.accelerator_manager and "speaker_verify" in self.accelerator_manager.gna_models:
            # Batch verify against all profiles
            for user_id, profile in self.profiles.items():
                # Prepare input for GNA model
                comparison = np.concatenate([embedding, profile.speaker_embedding])
                score = self.accelerator_manager.infer("speaker_verify", comparison)
                
                if score > best_score:
                    best_score = score
                    best_match = user_id
        else:
            # Fallback: cosine similarity
            for user_id, profile in self.profiles.items():
                similarity = 1 - cosine(embedding, profile.speaker_embedding)
                
                # Additional MFCC matching
                mfcc_similarity = 1 - cosine(features['mfcc_mean'], profile.mfcc_mean)
                
                # Combined score
                score = 0.7 * similarity + 0.3 * mfcc_similarity
                
                if score > best_score:
                    best_score = score
                    best_match = user_id
        
        # Check threshold
        if best_score >= self.identification_threshold:
            confidence = float(np.clip(best_score, 0, 1))
            logger.info(f"Identified speaker: {self.profiles[best_match].name} (confidence: {confidence:.2f})")
            return best_match, confidence
        
        return None, 0.0
    
    def verify_speaker(self, audio: np.ndarray, claimed_user_id: str) -> Tuple[bool, float]:
        """
        Verify if audio matches claimed identity
        Higher accuracy than identification
        """
        
        if claimed_user_id not in self.profiles:
            return False, 0.0
        
        profile = self.profiles[claimed_user_id]
        
        # Extract features
        features = self.extract_features(audio, detailed=True)
        embedding = self.create_embedding(audio)
        
        # Multiple verification methods
        scores = []
        
        # 1. Embedding similarity
        embedding_score = 1 - cosine(embedding, profile.speaker_embedding)
        scores.append(embedding_score)
        
        # 2. MFCC similarity
        mfcc_score = 1 - cosine(features['mfcc_mean'], profile.mfcc_mean)
        scores.append(mfcc_score)
        
        # 3. GMM likelihood
        if profile.gmm_model:
            feature_vec = np.concatenate([
                features['mfcc_mean'],
                features['mfcc_std'],
                features.get('mfcc_delta', np.zeros(self.n_mfcc))
            ]).reshape(1, -1)
            
            gmm_score = profile.gmm_model.score(feature_vec)
            # Normalize GMM score to [0, 1]
            gmm_score = 1 / (1 + np.exp(-gmm_score))
            scores.append(gmm_score)
        
        # 4. Pitch range check
        if 'pitch_range' in features:
            pitch_min, pitch_max = features['pitch_range']
            profile_min, profile_max = profile.pitch_range
            
            # Check if pitch is within expected range
            if profile_min <= pitch_min <= profile_max and profile_min <= pitch_max <= profile_max:
                scores.append(1.0)
            else:
                overlap = min(pitch_max, profile_max) - max(pitch_min, profile_min)
                range_size = max(profile_max - profile_min, pitch_max - pitch_min)
                pitch_score = max(0, overlap / range_size)
                scores.append(pitch_score)
        
        # Weighted average
        weights = [0.4, 0.2, 0.3, 0.1][:len(scores)]
        final_score = np.average(scores, weights=weights)
        
        verified = final_score >= self.verification_threshold
        confidence = float(np.clip(final_score, 0, 1))
        
        logger.info(f"Verification for {profile.name}: {verified} (confidence: {confidence:.2f})")
        
        return verified, confidence
    
    def adapt_profile(self, user_id: str, audio: np.ndarray, transcription: Optional[str] = None):
        """
        Continuously improve profile with new samples
        Self-learning mechanism
        """
        
        if user_id not in self.profiles:
            return
        
        profile = self.profiles[user_id]
        
        # Extract features from new sample
        features = self.extract_features(audio, detailed=True)
        embedding = self.create_embedding(audio)
        
        # Update profile with exponential moving average
        alpha = 0.1  # Learning rate
        
        # Update MFCC statistics
        profile.mfcc_mean = (1 - alpha) * profile.mfcc_mean + alpha * features['mfcc_mean']
        profile.mfcc_std = (1 - alpha) * profile.mfcc_std + alpha * features['mfcc_std']
        
        # Update embedding
        profile.speaker_embedding = (1 - alpha) * profile.speaker_embedding + alpha * embedding
        
        # Update pitch range
        if 'pitch_range' in features:
            new_min, new_max = features['pitch_range']
            old_min, old_max = profile.pitch_range
            profile.pitch_range = (
                min(old_min, new_min),
                max(old_max, new_max)
            )
        
        # Update statistics
        profile.num_samples += 1
        profile.total_duration += len(audio) / self.sample_rate
        profile.updated_at = datetime.now()
        
        # Update speech patterns if transcription provided
        if transcription:
            self._update_speech_patterns(profile, transcription)
        
        # Retrain GMM periodically
        if profile.num_samples % 10 == 0:
            # Queue for background retraining
            self.adaptation_queue.put((user_id, features))
        
        # Save updated profile
        self._save_profile(profile)
        
        logger.debug(f"Adapted profile for {profile.name} (sample #{profile.num_samples})")
    
    def _update_speech_patterns(self, profile: VoiceProfile, transcription: str):
        """Update linguistic patterns for better personalization"""
        
        if profile.common_phrases is None:
            profile.common_phrases = []
        if profile.pronunciation_variants is None:
            profile.pronunciation_variants = {}
        
        # Extract phrases (simplified - in production use NLP)
        words = transcription.lower().split()
        
        # Update common phrases
        for i in range(len(words) - 2):
            trigram = " ".join(words[i:i+3])
            if trigram not in profile.common_phrases:
                profile.common_phrases.append(trigram)
        
        # Keep only most recent phrases
        profile.common_phrases = profile.common_phrases[-100:]
    
    def detect_liveness(self, audio: np.ndarray) -> Tuple[bool, float]:
        """
        Detect if audio is live speech or replay attack
        Anti-spoofing mechanism
        """
        
        # Extract liveness features
        features = {}
        
        # 1. Check for microphone pop patterns (real speech)
        low_freq = librosa.feature.spectral_rolloff(y=audio, sr=self.sample_rate, roll_percent=0.01)
        features['has_pops'] = np.max(low_freq) > 50
        
        # 2. Check noise floor variation (real recording has ambient noise)
        noise_floor = np.percentile(np.abs(audio), 5)
        features['noise_variation'] = np.std(audio[np.abs(audio) < noise_floor * 2])
        
        # 3. Check for compression artifacts (replay often compressed)
        stft = librosa.stft(audio)
        phase_diff = np.diff(np.angle(stft), axis=1)
        features['phase_coherence'] = np.mean(np.abs(phase_diff))
        
        # 4. Formant bandwidth (real speech has natural variation)
        features['formant_variation'] = np.std(self._estimate_formants(audio))
        
        # Simple liveness score
        liveness_score = 0.0
        
        if features['has_pops']:
            liveness_score += 0.3
        if features['noise_variation'] > 0.0001:
            liveness_score += 0.3
        if features['phase_coherence'] < 2.0:
            liveness_score += 0.2
        if features['formant_variation'] > 100:
            liveness_score += 0.2
        
        is_live = liveness_score >= self.liveness_threshold
        
        return is_live, liveness_score
    
    def _save_profile(self, profile: VoiceProfile):
        """Save profile to disk"""
        
        profile_path = self.profile_dir / f"{profile.user_id}.json"
        
        # Save JSON data
        with open(profile_path, 'w') as f:
            json.dump(profile.to_dict(), f, indent=2)
        
        # Save GMM separately
        if profile.gmm_model:
            gmm_path = profile_path.with_suffix('.gmm')
            with open(gmm_path, 'wb') as f:
                pickle.dump(profile.gmm_model, f)
        
        logger.debug(f"Saved profile: {profile_path}")
    
    def export_profile(self, user_id: str, export_path: str):
        """Export profile for backup or transfer"""
        
        if user_id not in self.profiles:
            raise ValueError(f"Profile {user_id} not found")
        
        profile = self.profiles[user_id]
        export_data = {
            'profile': profile.to_dict(),
            'version': '1.0',
            'exported_at': datetime.now().isoformat()
        }
        
        with open(export_path, 'w') as f:
            json.dump(export_data, f, indent=2)
        
        logger.info(f"Exported profile to {export_path}")
    
    def get_profile_stats(self, user_id: str) -> Dict[str, Any]:
        """Get statistics about a user's voice profile"""
        
        if user_id not in self.profiles:
            return {}
        
        profile = self.profiles[user_id]
        
        stats = {
            'name': profile.name,
            'num_samples': profile.num_samples,
            'total_duration': profile.total_duration,
            'avg_pitch': np.mean(profile.pitch_range),
            'pitch_range': profile.pitch_range,
            'voice_quality': profile.voice_quality,
            'last_updated': profile.updated_at.isoformat(),
            'confidence_threshold': profile.confidence_threshold
        }
        
        return stats