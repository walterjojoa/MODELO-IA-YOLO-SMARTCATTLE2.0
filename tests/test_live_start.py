"""The service must not open anything by itself: on another PC, a copied .env would point it at someone else's camera."""

import importlib.util
from pathlib import Path

import pytest

SPEC = importlib.util.spec_from_file_location("live_entry", Path(__file__).resolve().parents[1] / "live.py")
live_entry = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(live_entry)


class FakeServer:
    server_address = ("127.0.0.1", 0)

    def serve_forever(self, poll_interval=0.5):
        raise KeyboardInterrupt

    def server_close(self):
        pass


class FakeDetector:
    loaded = False

    def __init__(self, settings):
        pass

    @property
    def class_ids(self):
        FakeDetector.loaded = True
        return []


@pytest.fixture
def run(monkeypatch, tmp_path):
    opened, saved = [], tmp_path / "cameras.json"
    saved.write_text('[{"camera_id": "cam-old", "source": "rtsp://192.168.100.30/live"}]', encoding="utf-8")
    FakeDetector.loaded = False
    for name in ("SMARTCATTLE_AUTOSTART_CAMERA", "SMARTCATTLE_BACKEND_URL", "SMARTCATTLE_LIVE_TUNNEL",
                 "SMARTCATTLE_LIVE_PUBLIC_URL", "RENDER_EXTERNAL_URL", "SMARTCATTLE_CLOUD",
                 "IMOU_APP_ID", "IMOU_APP_SECRET", "IMOU_DEVICE_ID", "IMOU_PROFILE"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("CAMERA_URL", "rtsp://192.168.100.30/live")
    monkeypatch.setenv("SMARTCATTLE_CAMERAS_FILE", str(saved))
    monkeypatch.setattr(live_entry, "load_env_file", lambda: None)
    monkeypatch.setattr(live_entry, "Detector", FakeDetector)
    monkeypatch.setattr(live_entry, "make_server", lambda *args, **kwargs: FakeServer())

    class RecordingStream:
        def __init__(self, source, **kwargs):
            opened.append(source)

        def on_state_change(self, callback):
            pass

        def stop(self):
            pass

        def read(self):
            raise OSError("no camera in this test")

    monkeypatch.setattr(live_entry, "CameraStream", RecordingStream)
    monkeypatch.setattr(live_entry, "capture_worker", lambda *args, **kwargs: None)
    monkeypatch.setattr(live_entry, "detection_worker", lambda *args, **kwargs: None)
    return lambda *argv: (live_entry.main(list(argv)), opened)


def test_with_no_url_nothing_opens_even_with_another_pcs_camera_in_the_settings(run):
    code, opened = run()
    assert code == 0
    assert opened == []
    assert FakeDetector.loaded is False


def test_a_url_on_the_command_line_is_still_opened(run):
    _, opened = run("--url", "1")
    assert opened == ["1"]


def test_the_settings_camera_opens_only_when_asked_for(run):
    _, opened = run("--auto-camera")
    assert "rtsp://192.168.100.30/live" in opened


def test_in_the_cloud_the_settings_camera_is_the_imou_cloud_never_the_lan_one(run, monkeypatch):
    monkeypatch.setenv("SMARTCATTLE_CLOUD", "1")
    monkeypatch.setenv("IMOU_APP_ID", "app")
    monkeypatch.setenv("IMOU_APP_SECRET", "secret")
    monkeypatch.setenv("IMOU_DEVICE_ID", "device-1")
    monkeypatch.setenv("IMOU_PROFILE", "SD")
    code, opened = run("--auto-camera")
    assert code == 0
    assert [str(source) for source in opened] == ["Imou cloud device device-1 (SD)"]


def test_in_the_cloud_without_imou_settings_it_refuses_to_start_instead_of_trying_rtsp(run, monkeypatch, capsys):
    monkeypatch.setenv("SMARTCATTLE_CLOUD", "1")
    code, opened = run("--auto-camera")
    assert code == 1
    assert opened == []
    assert "IMOU_APP_ID" in capsys.readouterr().err


@pytest.mark.parametrize("url", ["1", "192.168.168.190:554", "rtsp://admin:x@192.168.1.20/live"])
def test_in_the_cloud_a_local_camera_on_the_command_line_is_refused(run, monkeypatch, url):
    monkeypatch.setenv("SMARTCATTLE_CLOUD", "1")
    code, opened = run("--url", url)
    assert code == 1
    assert opened == []
