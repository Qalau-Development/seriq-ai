import numpy as np
import pytest

from seriq_engine.classifier import decide, signal_quality


# test_decide_labels — правила api.md: confidence = max(p, 1 − p), метка по p
@pytest.mark.parametrize(
    ("p", "label", "confidence"),
    [(0.95, "complete", 0.95), (0.05, "incomplete", 0.95), (0.6, "uncertain", 0.6), (0.3, "uncertain", 0.7)],
)
def test_decide_labels(p, label, confidence):
    assert decide(p, quality_ok=True, threshold=0.75) == (label, pytest.approx(confidence))


# test_decide_bad_signal — при плохом сигнале всегда uncertain
def test_decide_bad_signal():
    assert decide(0.99, quality_ok=False)[0] == "uncertain"


# test_signal_quality_ok — сигнал без пропусков проходит пороги
def test_signal_quality_ok():
    q = signal_quality(np.linspace(90, 180, 100), sample_fps=10)
    assert q.ok and q.detected_share == 1.0 and q.longest_gap_s == 0


# test_signal_quality_long_gap — пропуск длиннее 2 с делает сигнал плохим
def test_signal_quality_long_gap():
    angles = np.linspace(90, 180, 100)
    angles[40:65] = np.nan
    q = signal_quality(angles, sample_fps=10)
    assert q.longest_gap_s == pytest.approx(2.5) and not q.ok


# test_signal_quality_short — меньше 20 точек угла — плохой сигнал
def test_signal_quality_short():
    assert not signal_quality(np.linspace(90, 180, 15), sample_fps=10).ok
