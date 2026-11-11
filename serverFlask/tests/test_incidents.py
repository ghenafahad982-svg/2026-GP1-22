"""Isolated, no-network tests for Raqeeb's GET /incidents endpoint.
Run from the repository root: python -m unittest discover -s serverFlask/tests -v
"""
import importlib.util
import os
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


class IncidentApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Provide test doubles BEFORE loading app.py, so no cloud credentials
        # or network access are needed.
        firebase_admin = types.ModuleType("firebase_admin")
        firebase_admin._apps = [object()]
        credentials = types.ModuleType("firebase_admin.credentials")
        firestore = types.ModuleType("firebase_admin.firestore")
        auth = types.ModuleType("firebase_admin.auth")
        firestore.client = MagicMock()
        firestore.SERVER_TIMESTAMP = object()
        firebase_admin.credentials = credentials
        firebase_admin.firestore = firestore
        firebase_admin.auth = auth

        supabase = types.ModuleType("supabase")
        supabase.create_client = MagicMock(return_value=MagicMock())

        fake_modules = {
            "firebase_admin": firebase_admin,
            "firebase_admin.credentials": credentials,
            "firebase_admin.firestore": firestore,
            "firebase_admin.auth": auth,
            "supabase": supabase,
        }
        fake_env = {
            "SUPABASE_URL": "https://example.invalid",
            "SUPABASE_SECRET_KEY": "test-placeholder-not-real",
            "SUPABASE_BUCKET": "incident-videos",
            "DEVICE_API_TOKEN": "test-device-token-not-real",
            "FIREBASE_SERVICE_ACCOUNT": "{}",
        }
        with patch.dict(sys.modules, fake_modules), patch.dict(os.environ, fake_env):
            spec = importlib.util.spec_from_file_location(
                "raqeeb_app_under_test",
                Path(__file__).resolve().parents[1] / "app.py",
            )
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)

        cls.raqeeb = module
        cls.auth = auth
        cls.db = module.db

    def setUp(self):
        self.client = self.raqeeb.app.test_client()
        self.db.reset_mock()
        self.auth.verify_id_token = MagicMock(return_value={"uid": "officer-uid"})
        self.user_doc = MagicMock()
        self.user_doc.exists = True
        self.user_doc.to_dict.return_value = {
            "role": "officer", "deviceId": "raqeeb-001"
        }
        self.db.collection.return_value.document.return_value.get.return_value = self.user_doc

    def get(self, token=True):
        headers = {"Authorization": "Bearer example-test-token"} if token else {}
        return self.client.get("/incidents", headers=headers)

    def test_missing_token_returns_401(self):
        response = self.get(token=False)
        self.assertEqual(response.status_code, 401)
        self.auth.verify_id_token.assert_not_called()

    def test_invalid_token_returns_401(self):
        self.auth.verify_id_token.side_effect = ValueError("invalid test token")
        self.assertEqual(self.get().status_code, 401)

    def test_admin_cannot_use_officer_endpoint(self):
        self.user_doc.to_dict.return_value = {
            "role": "admin", "deviceId": "raqeeb-001"
        }
        self.assertEqual(self.get().status_code, 403)

    def test_officer_without_assigned_device_returns_403(self):
        self.user_doc.to_dict.return_value = {"role": "officer"}
        self.assertEqual(self.get().status_code, 403)

    def test_officer_receives_only_assigned_device_incidents(self):
        incident_doc = MagicMock()
        incident_doc.id = "event-test-1"
        incident_doc.to_dict.return_value = {
            "deviceId": "raqeeb-001",
            "detectionType": "knife",
            "confidence": 0.92,
            "createdAt": None,
            "videoPath": "incidents/event-test-1/clip.mp4",
        }
        query = self.db.collection.return_value.where.return_value
        query.stream.return_value = [incident_doc]

        response = self.get()
        self.assertEqual(response.status_code, 200)
        payload = response.get_json()
        self.assertTrue(payload["success"])
        self.assertEqual(len(payload["incidents"]), 1)
        self.assertEqual(payload["incidents"][0]["eventId"], "event-test-1")
        self.assertEqual(payload["incidents"][0]["status"], "pending")
        self.assertTrue(payload["incidents"][0]["videoAvailable"])
        self.db.collection.return_value.where.assert_called_once_with(
            "deviceId", "==", "raqeeb-001"
        )
        self.assertNotIn("videoPath", str(payload))
        self.assertNotIn("SUPABASE_SECRET_KEY", str(payload))


if __name__ == "__main__":
    unittest.main()
