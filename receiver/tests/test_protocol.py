import json
import unittest

from receiver.protocol import parse_report


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.report = dict(v=1, token="012345", seq=0, lx=0, ly=1,
                           rx=-0.5, ry=0.2, buttons=["cross", "d_up"])

    def decode(self):
        return parse_report(json.dumps(self.report).encode(), "012345")

    def test_valid(self):
        parsed = self.decode()
        self.assertEqual(parsed.ly, 1.0)
        self.assertIn("cross", parsed.buttons)

    def test_incorrect_pin(self):
        self.report["token"] = "654321"
        self.assertIsNone(self.decode())

    def test_invalid_button(self):
        self.report["buttons"] = ["unknown"]
        self.assertIsNone(self.decode())

    def test_out_of_range_stick(self):
        self.report["lx"] = 2
        self.assertIsNone(self.decode())

    def test_nan(self):
        self.report["rx"] = float("nan")
        self.assertIsNone(self.decode())

    def test_bad_sequence(self):
        self.report["seq"] = -1
        self.assertIsNone(self.decode())

    def test_malformed(self):
        self.assertIsNone(parse_report(b"bad json", "012345"))

    def test_oversized(self):
        self.assertIsNone(parse_report(b"x" * 2049, "012345"))


if __name__ == "__main__":
    unittest.main()
