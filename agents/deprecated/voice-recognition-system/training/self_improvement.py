"""
Self-Improvement and Adaptation Pipeline
Continuously learns from your voice patterns and corrections
"""

import numpy as np
from typing import Dict, List, Optional, Tuple, Any
from pathlib import Path
import json
import pickle
import time
from datetime import datetime, timedelta
import threading
import queue
from dataclasses import dataclass, field
import logging
import sqlite3
from collections import defaultdict, Counter
import Levenshtein

logger = logging.getLogger(__name__)


@dataclass
class CorrectionEntry:
    """Single correction made by user"""
    timestamp: datetime
    original_text: str
    corrected_text: str
    audio_hash: str
    confidence: float
    context: Optional[str] = None
    correction_type: Optional[str] = None  # word, punctuation, grammar


@dataclass
class AdaptationData:
    """Data for model adaptation"""
    audio_features: np.ndarray
    original_transcription: str
    corrected_transcription: str
    speaker_id: str
    timestamp: datetime
    metadata: Dict[str, Any] = field(default_factory=dict)


class PersonalLanguageModel:
    """
    Personal language model that learns user's speaking style
    """
    
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.vocabulary = set()
        self.ngrams = {
            'unigrams': Counter(),
            'bigrams': Counter(),
            'trigrams': Counter()
        }
        self.corrections = defaultdict(Counter)  # original -> corrected mappings
        self.context_patterns = defaultdict(list)
        
    def update(self, text: str):
        """Update model with new text"""
        
        words = text.lower().split()
        
        # Update vocabulary
        self.vocabulary.update(words)
        
        # Update n-grams
        self.ngrams['unigrams'].update(words)
        
        for i in range(len(words) - 1):
            bigram = f"{words[i]} {words[i+1]}"
            self.ngrams['bigrams'][bigram] += 1
        
        for i in range(len(words) - 2):
            trigram = f"{words[i]} {words[i+1]} {words[i+2]}"
            self.ngrams['trigrams'][trigram] += 1
    
    def add_correction(self, original: str, corrected: str):
        """Learn from correction"""
        
        self.corrections[original.lower()][corrected.lower()] += 1
        
        # Analyze correction type
        original_words = original.split()
        corrected_words = corrected.split()
        
        if len(original_words) == len(corrected_words):
            # Word-level corrections
            for orig, corr in zip(original_words, corrected_words):
                if orig != corr:
                    self.corrections[orig.lower()][corr.lower()] += 1
    
    def predict_correction(self, text: str) -> Optional[str]:
        """Predict correction based on history"""
        
        words = text.split()
        corrected_words = []
        
        for word in words:
            word_lower = word.lower()
            if word_lower in self.corrections:
                # Get most likely correction
                corrections = self.corrections[word_lower]
                if corrections:
                    best_correction = max(corrections, key=corrections.get)
                    # Preserve original case
                    if word[0].isupper():
                        best_correction = best_correction.capitalize()
                    corrected_words.append(best_correction)
                else:
                    corrected_words.append(word)
            else:
                corrected_words.append(word)
        
        return " ".join(corrected_words)
    
    def get_suggestions(self, partial_text: str, n: int = 3) -> List[str]:
        """Get word/phrase suggestions"""
        
        words = partial_text.lower().split()
        suggestions = []
        
        if len(words) >= 2:
            # Try trigram prediction
            bigram_prefix = f"{words[-2]} {words[-1]}"
            for trigram, count in self.ngrams['trigrams'].most_common():
                if trigram.startswith(bigram_prefix):
                    next_word = trigram.split()[2]
                    suggestions.append(next_word)
                    if len(suggestions) >= n:
                        break
        
        if len(suggestions) < n and len(words) >= 1:
            # Try bigram prediction
            last_word = words[-1]
            for bigram, count in self.ngrams['bigrams'].most_common():
                if bigram.startswith(last_word):
                    next_word = bigram.split()[1]
                    if next_word not in suggestions:
                        suggestions.append(next_word)
                        if len(suggestions) >= n:
                            break
        
        return suggestions[:n]


class SelfImprovementEngine:
    """
    Main self-improvement system that coordinates learning
    """
    
    def __init__(self,
                 data_dir: str = "./data/training_sets",
                 db_path: str = "./data/corrections.db"):
        
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = db_path
        
        # Components
        self.personal_models: Dict[str, PersonalLanguageModel] = {}
        self.adaptation_queue = queue.Queue()
        self.correction_history: List[CorrectionEntry] = []
        
        # Training parameters
        self.min_corrections_for_training = 10
        self.adaptation_batch_size = 32
        self.learning_rate = 0.01
        
        # Metrics
        self.metrics = {
            'total_corrections': 0,
            'total_adaptations': 0,
            'accuracy_improvement': 0.0,
            'common_errors': Counter(),
            'correction_types': Counter()
        }
        
        # Background processing
        self.processing_thread = None
        self.is_running = False
        
        self._init_database()
        self._load_history()
    
    def _init_database(self):
        """Initialize corrections database"""
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS corrections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                speaker_id TEXT,
                original_text TEXT,
                corrected_text TEXT,
                audio_hash TEXT,
                confidence REAL,
                context TEXT,
                correction_type TEXT
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS adaptation_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                speaker_id TEXT,
                audio_features BLOB,
                original_text TEXT,
                corrected_text TEXT,
                metadata TEXT
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS metrics (
                timestamp DATETIME,
                metric_name TEXT,
                metric_value REAL,
                speaker_id TEXT
            )
        """)
        
        conn.commit()
        conn.close()
    
    def _load_history(self):
        """Load correction history from database"""
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT timestamp, original_text, corrected_text, audio_hash, 
                   confidence, context, correction_type
            FROM corrections
            ORDER BY timestamp DESC
            LIMIT 1000
        """)
        
        for row in cursor.fetchall():
            entry = CorrectionEntry(
                timestamp=datetime.fromisoformat(row[0]),
                original_text=row[1],
                corrected_text=row[2],
                audio_hash=row[3],
                confidence=row[4],
                context=row[5],
                correction_type=row[6]
            )
            self.correction_history.append(entry)
        
        conn.close()
        
        logger.info(f"Loaded {len(self.correction_history)} historical corrections")
    
    def start(self):
        """Start background processing"""
        
        if self.is_running:
            return
        
        self.is_running = True
        self.processing_thread = threading.Thread(target=self._process_adaptations)
        self.processing_thread.daemon = True
        self.processing_thread.start()
        
        logger.info("Self-improvement engine started")
    
    def stop(self):
        """Stop background processing"""
        
        self.is_running = False
        if self.processing_thread:
            self.processing_thread.join(timeout=5)
        
        logger.info("Self-improvement engine stopped")
    
    def add_correction(self,
                      original: str,
                      corrected: str,
                      speaker_id: str,
                      audio_features: Optional[np.ndarray] = None,
                      confidence: float = 0.0):
        """
        Add a correction for learning
        
        Args:
            original: Original transcription
            corrected: User-corrected transcription
            speaker_id: Speaker identifier
            audio_features: Audio features for adaptation
            confidence: Original transcription confidence
        """
        
        # Analyze correction
        correction_type = self._analyze_correction_type(original, corrected)
        
        # Create correction entry
        entry = CorrectionEntry(
            timestamp=datetime.now(),
            original_text=original,
            corrected_text=corrected,
            audio_hash=self._hash_audio_features(audio_features),
            confidence=confidence,
            correction_type=correction_type
        )
        
        # Save to database
        self._save_correction(entry, speaker_id)
        
        # Update personal model
        if speaker_id not in self.personal_models:
            self.personal_models[speaker_id] = PersonalLanguageModel(speaker_id)
        
        model = self.personal_models[speaker_id]
        model.add_correction(original, corrected)
        model.update(corrected)
        
        # Queue for adaptation if audio features provided
        if audio_features is not None:
            adaptation = AdaptationData(
                audio_features=audio_features,
                original_transcription=original,
                corrected_transcription=corrected,
                speaker_id=speaker_id,
                timestamp=datetime.now()
            )
            self.adaptation_queue.put(adaptation)
        
        # Update metrics
        self.metrics['total_corrections'] += 1
        self.metrics['correction_types'][correction_type] += 1
        
        # Track common errors
        if len(original) > 0:
            error_pattern = self._extract_error_pattern(original, corrected)
            if error_pattern:
                self.metrics['common_errors'][error_pattern] += 1
        
        logger.debug(f"Added correction: '{original}' -> '{corrected}' (type: {correction_type})")
    
    def _analyze_correction_type(self, original: str, corrected: str) -> str:
        """Determine type of correction"""
        
        if original.lower() == corrected.lower():
            return "capitalization"
        
        original_words = original.split()
        corrected_words = corrected.split()
        
        if len(original_words) != len(corrected_words):
            return "insertion_deletion"
        
        # Check for word substitutions
        different_words = sum(1 for o, c in zip(original_words, corrected_words) if o != c)
        
        if different_words == 1:
            return "single_word"
        elif different_words > 1:
            return "multiple_words"
        
        # Check for punctuation
        if any(p in corrected for p in '.,!?;:'):
            return "punctuation"
        
        return "other"
    
    def _extract_error_pattern(self, original: str, corrected: str) -> Optional[str]:
        """Extract common error pattern"""
        
        ops = Levenshtein.editops(original, corrected)
        
        if not ops:
            return None
        
        # Get first operation as pattern
        op_type, orig_pos, corr_pos = ops[0]
        
        if op_type == 'replace':
            if orig_pos < len(original) and corr_pos < len(corrected):
                return f"replace_{original[orig_pos]}_{corrected[corr_pos]}"
        elif op_type == 'insert':
            if corr_pos < len(corrected):
                return f"insert_{corrected[corr_pos]}"
        elif op_type == 'delete':
            if orig_pos < len(original):
                return f"delete_{original[orig_pos]}"
        
        return None
    
    def _hash_audio_features(self, features: Optional[np.ndarray]) -> str:
        """Create hash of audio features"""
        
        if features is None:
            return ""
        
        # Simple hash based on feature statistics
        feature_str = f"{np.mean(features):.4f}_{np.std(features):.4f}_{len(features)}"
        return str(hash(feature_str))
    
    def _save_correction(self, entry: CorrectionEntry, speaker_id: str):
        """Save correction to database"""
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO corrections 
            (timestamp, speaker_id, original_text, corrected_text, 
             audio_hash, confidence, context, correction_type)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            entry.timestamp.isoformat(),
            speaker_id,
            entry.original_text,
            entry.corrected_text,
            entry.audio_hash,
            entry.confidence,
            entry.context,
            entry.correction_type
        ))
        
        conn.commit()
        conn.close()
    
    def _process_adaptations(self):
        """Background thread for processing adaptations"""
        
        batch = []
        
        while self.is_running:
            try:
                # Collect batch
                adaptation = self.adaptation_queue.get(timeout=1.0)
                batch.append(adaptation)
                
                # Process batch when full
                if len(batch) >= self.adaptation_batch_size:
                    self._adapt_models(batch)
                    batch = []
                    
            except queue.Empty:
                # Process partial batch if old enough
                if batch and (datetime.now() - batch[0].timestamp) > timedelta(minutes=5):
                    self._adapt_models(batch)
                    batch = []
            except Exception as e:
                logger.error(f"Adaptation processing error: {e}")
    
    def _adapt_models(self, batch: List[AdaptationData]):
        """Adapt models with batch of corrections"""
        
        if not batch:
            return
        
        logger.info(f"Adapting models with {len(batch)} corrections")
        
        # Group by speaker
        speaker_batches = defaultdict(list)
        for adaptation in batch:
            speaker_batches[adaptation.speaker_id].append(adaptation)
        
        for speaker_id, speaker_batch in speaker_batches.items():
            # Prepare training data
            audio_features = np.array([a.audio_features for a in speaker_batch])
            original_texts = [a.original_transcription for a in speaker_batch]
            corrected_texts = [a.corrected_transcription for a in speaker_batch]
            
            # Here you would actually fine-tune the model
            # This is a placeholder for the actual training logic
            
            # Update metrics
            self.metrics['total_adaptations'] += len(speaker_batch)
            
            # Save adaptation data
            self._save_adaptation_data(speaker_batch)
        
        # Estimate accuracy improvement
        self._update_accuracy_metrics()
    
    def _save_adaptation_data(self, batch: List[AdaptationData]):
        """Save adaptation data for future training"""
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        for adaptation in batch:
            cursor.execute("""
                INSERT INTO adaptation_data
                (timestamp, speaker_id, audio_features, original_text, 
                 corrected_text, metadata)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                adaptation.timestamp.isoformat(),
                adaptation.speaker_id,
                pickle.dumps(adaptation.audio_features),
                adaptation.original_transcription,
                adaptation.corrected_transcription,
                json.dumps(adaptation.metadata)
            ))
        
        conn.commit()
        conn.close()
    
    def _update_accuracy_metrics(self):
        """Calculate accuracy improvement over time"""
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get recent corrections
        cursor.execute("""
            SELECT confidence, correction_type
            FROM corrections
            WHERE timestamp > datetime('now', '-7 days')
        """)
        
        recent_corrections = cursor.fetchall()
        
        if recent_corrections:
            avg_confidence = np.mean([c[0] for c in recent_corrections])
            
            # Simple improvement estimation
            # Lower confidence on original = more improvement needed
            improvement = (1.0 - avg_confidence) * 0.1  # 10% of error rate
            
            self.metrics['accuracy_improvement'] = (
                self.metrics['accuracy_improvement'] * 0.9 + improvement * 0.1
            )
            
            # Save metric
            cursor.execute("""
                INSERT INTO metrics (timestamp, metric_name, metric_value, speaker_id)
                VALUES (?, ?, ?, ?)
            """, (
                datetime.now().isoformat(),
                'accuracy_improvement',
                self.metrics['accuracy_improvement'],
                'system'
            ))
        
        conn.commit()
        conn.close()
    
    def get_suggestions(self, 
                        partial_text: str, 
                        speaker_id: str,
                        n: int = 3) -> List[str]:
        """Get personalized suggestions"""
        
        if speaker_id in self.personal_models:
            return self.personal_models[speaker_id].get_suggestions(partial_text, n)
        return []
    
    def predict_correction(self, text: str, speaker_id: str) -> Optional[str]:
        """Predict correction based on history"""
        
        if speaker_id in self.personal_models:
            return self.personal_models[speaker_id].predict_correction(text)
        return None
    
    def get_common_errors(self, speaker_id: Optional[str] = None, n: int = 10) -> List[Tuple[str, int]]:
        """Get most common errors"""
        
        if speaker_id and speaker_id in self.personal_models:
            model = self.personal_models[speaker_id]
            errors = []
            for original, corrections in model.corrections.items():
                total = sum(corrections.values())
                errors.append((original, total))
            return sorted(errors, key=lambda x: x[1], reverse=True)[:n]
        
        return self.metrics['common_errors'].most_common(n)
    
    def export_personal_model(self, speaker_id: str, export_path: str):
        """Export personal language model"""
        
        if speaker_id not in self.personal_models:
            raise ValueError(f"No model for speaker {speaker_id}")
        
        model = self.personal_models[speaker_id]
        
        export_data = {
            'speaker_id': speaker_id,
            'vocabulary': list(model.vocabulary),
            'ngrams': {
                'unigrams': dict(model.ngrams['unigrams']),
                'bigrams': dict(model.ngrams['bigrams']),
                'trigrams': dict(model.ngrams['trigrams'])
            },
            'corrections': dict(model.corrections),
            'exported_at': datetime.now().isoformat()
        }
        
        with open(export_path, 'w') as f:
            json.dump(export_data, f, indent=2)
        
        logger.info(f"Exported personal model to {export_path}")
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get improvement metrics"""
        
        metrics = self.metrics.copy()
        
        # Add derived metrics
        if metrics['total_corrections'] > 0:
            metrics['avg_corrections_per_day'] = (
                metrics['total_corrections'] / 
                max(1, (datetime.now() - self.correction_history[0].timestamp).days)
                if self.correction_history else 0
            )
        
        return metrics