import socket
import time
import math
import sys
import argparse
import json
import os
from dataclasses import dataclass
from typing import List, Dict, Any

# This is our local IP
HOST = "192.168.0.101"
# HOST = "192.168.0.100"
DEST = "192.168.0.2"
PORT = 8192  # 0x2000


def _parse_int_auto(val):
    if isinstance(val, int):
        return val
    if isinstance(val, str):
        v = val.strip().replace("_", "")
        try:
            return int(v, 0)  # honors 0x, 0o, 0b, or decimal
        except Exception:
            return int(v, 16)  # hex without prefix
    raise ValueError(f"Unsupported int value: {val}")


def apply_config_from_spec(spec_path):
    """
    Read base_addr, w_data, and depth from a spec JSON.
    Accepts top-level keys or under 'capture'.
    """
    global base_addr, w_data, depth, num_ram, w_ram, w_addr
    try:
        with open(spec_path, "r") as f:
            spec = json.load(f)
    except Exception as e:
        print(f"Warning: failed to read spec at {spec_path}: {e}")
        return
    src = spec.get("capture", spec)
    if "base_addr" in src:
        try:
            base_addr = _parse_int_auto(src["base_addr"])
        except Exception as e:
            print(f"Warning: invalid base_addr in spec: {e}")
    if "w_data" in src:
        try:
            w_data = int(src["w_data"])
        except Exception as e:
            print(f"Warning: invalid w_data in spec: {e}")
    if "depth" in src:
        try:
            depth = int(src["depth"])
        except Exception as e:
            print(f"Warning: invalid depth in spec: {e}")
    # recompute derived
    num_ram = (w_data + 31) // 32
    w_ram = int(math.log2(num_ram))
    w_addr = int(math.log2(depth))


# Defaults (overridden by --spec argument)
base_addr = 0x3000_0000
w_data = 256
depth = 65536
num_ram = (w_data + 31) // 32
w_ram = int(math.log2(num_ram))
w_addr = int(math.log2(depth))

print(f"UDP target {DEST}:{PORT}")

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, 11, 1)
s.settimeout(1)
s.bind((HOST, PORT))

def hex_to_str(val):
    return str(hex(val)).replace("0x","").zfill(8).upper()

def str_to_hex(val):
    return "0x" + val.lstrip("0")

seq = 0
def write_dword(addr, data, debug='0'):
    global seq
    flags = "01"
    cmd = "04"
    #print("WRITE:",addr,data)
    packet = cmd + flags + str(seq).zfill(4) + '0000' + hex_to_str(addr) + hex_to_str(data)
    s.sendto(bytes.fromhex(packet), (DEST, PORT))
    ack, ip_addr = s.recvfrom(1024)
    seq = str(ack[14:16].hex()).upper()
    time.sleep(0.001)

def read_dword(addr):
    global seq
    #print("READ:",addr)
    flags = "00"
    cmd = "14"
    packet = cmd + flags + str(seq).zfill(4) + '0000' + hex_to_str(addr)
    s.sendto(bytes.fromhex(packet), (DEST, PORT))
    data, addr = s.recvfrom(1024)
    data_hex = str(data[10:].hex()).upper()
    val_hex = data_hex[0:8]
    try:
        return int(val_hex, 16)
    except Exception:
        return 0


def enable_capture():
    #print("CONFIGURED:",hex(base_addr))
    write_dword(base_addr + 0x0000, 0x0000_0001) # Enable capture

def wait_for_capture(timeout=50): # 5000ms timeout
    while timeout > 0:
        time.sleep(0.1)
        val = read_dword(base_addr + 0x80)
        if (val & 0x2) == 0x2:
            return True
        timeout -= 1
        #print(hex(val))
        #print(hex(read_dword(base_addr + 0x84)))
    return False

def disable_capture():
    write_dword(base_addr + 0x0000, 0x0000_0000) # Disable capture

def reset_capture():
    write_dword(base_addr + 0x0000, 0x0000_0002) # Reset capture
    time.sleep(1)
    write_dword(base_addr + 0x0000, 0x0000_0000) # Disable capture

def dump_capture():
    samples = []
    #print(w_addr,w_ram,depth)
    for i in range(depth):
        sample = []
        for y in range(num_ram):
            ram_addr = y<<(w_addr+2)
            sample_addr = (i*0x4)
            ctrl_switch = 1 << (w_addr + 2 + w_ram)
            data = read_dword(base_addr + ram_addr + sample_addr + ctrl_switch)
            #print(base_addr,ram_addr,sample_addr,data)
            #print(hex(base_addr + ram_addr + sample_addr + ctrl_switch),hex(data))
            sample.append(data)
        samples.append(sample)
    return samples

def dump_capture_to_file(path):
    """
    Captures and writes raw samples to a JSON file as a list of samples,
    where each sample is a list of 32-bit words (ints). Compatible with viewer.py --from-file.
    """
    payload = dump_capture()
    with open(path, "w") as f:
        json.dump(payload, f)
    print(f"Wrote {len(payload)} samples to {path}")

@dataclass
class SignalDef:
    name: str
    lsb: int
    width: int
    radix: str = "hex"

    def extract(self, sample_value: int) -> int:
        if self.width <= 0:
            return 0
        mask = (1 << self.width) - 1
        return (sample_value >> self.lsb) & mask

    def format_value(self, value: int) -> str:
        if self.radix == "bin":
            return f"0b{value:0{self.width}b}"
        if self.radix == "unsigned":
            return str(value)
        if self.radix == "signed":
            sign_bit = 1 << (self.width - 1)
            max_mask = (1 << self.width) - 1
            value &= max_mask
            if value & sign_bit:
                value = value - (1 << self.width)
            return str(value)
        hex_width = (self.width + 3) // 4
        return f"0x{value:0{hex_width}X}"

def parse_signals(sig_spec: List[Dict[str, Any]]) -> List[SignalDef]:
    signals: List[SignalDef] = []
    for entry in sig_spec:
        signals.append(
            SignalDef(
                name=entry["name"],
                lsb=int(entry["lsb"]),
                width=int(entry["width"]),
                radix=entry.get("radix", "hex"),
            )
        )
    return signals

def to_int(word: Any) -> int:
    if isinstance(word, int):
        return word
    if isinstance(word, str):
        word = word.strip()
        if word.startswith("0x") or word.startswith("0X"):
            return int(word, 16)
        try:
            return int(word, 16)
        except Exception:
            return int(word, 10)
    raise TypeError(f"Unsupported word type: {type(word)}")

def combine_words_32(words32: List[Any], order: str = "lsw_first") -> int:
    w = [to_int(x) & 0xFFFF_FFFF for x in words32]
    if order == "lsw_first":
        val = 0
        for i, word in enumerate(w):
            val |= (word << (32 * i))
        return val
    elif order == "msw_first":
        val = 0
        for word in w:
            val = (val << 32) | word
        return val
    else:
        raise ValueError("order must be 'lsw_first' or 'msw_first'")

def build_samples_combined(samples_words: List[List[Any]], order: str) -> List[int]:
    return [combine_words_32(words, order=order) for words in samples_words]

def extract_signal_traces(samples128: List[int], signals: List[SignalDef]) -> Dict[str, List[int]]:
    traces: Dict[str, List[int]] = {}
    for sig in signals:
        traces[sig.name] = [sig.extract(s) for s in samples128]
    return traces

def write_csv(traces: Dict[str, List[int]], signals: List[SignalDef], path: str) -> None:
    import csv
    num_samples = len(next(iter(traces.values()))) if traces else 0
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        header = ["Sample"] + [sig.name for sig in signals]
        writer.writerow(header)
        for i in range(num_samples):
            row = [i]
            for sig in signals:
                val = traces[sig.name][i]
                row.append(sig.format_value(val))
            writer.writerow(row)

def load_signal_spec_from_file(path: str) -> List[SignalDef]:
    with open(path, "r") as f:
        spec = json.load(f)
    if not isinstance(spec, dict) or "signals" not in spec:
        raise ValueError("Signal spec JSON must be an object with a 'signals' list.")
    return parse_signals(spec["signals"])

def get_spec_capture_depth(path: str) -> int | None:
    try:
        with open(path, "r") as f:
            spec = json.load(f)
    except Exception:
        return None
    if not isinstance(spec, dict):
        return None
    if "capture" in spec and isinstance(spec["capture"], dict) and "depth" in spec["capture"]:
        try:
            return int(spec["capture"]["depth"])
        except Exception:
            return None
    if "depth" in spec:
        try:
            return int(spec["depth"])
        except Exception:
            return None
    return None

def post_process_samples(samples_words: List[List[Any]], spec_path: str, order: str = "lsw_first", csv_path: str | None = None) -> str | None:
    """
    Parse in-memory samples and write CSV of traces based on the provided spec.
    Returns the CSV path on success, or None on failure.
    """
    try:
        signals = load_signal_spec_from_file(spec_path)
    except Exception as e:
        print(f"Post-process (mem): failed to load signal spec '{spec_path}': {e}")
        return None
    if not isinstance(samples_words, list):
        print("Post-process (mem): samples must be a list of samples")
        return None
    # Honor depth from spec if present
    spec_depth = get_spec_capture_depth(spec_path)
    if spec_depth is not None:
        samples_words = samples_words[:spec_depth]
    # Build traces and write CSV
    combined_samples = build_samples_combined(samples_words, order=order)
    traces = extract_signal_traces(combined_samples, signals)
    if csv_path is None:
        print("Post-process (mem): no CSV path provided")
        return None
    try:
        write_csv(traces, signals, csv_path)
        print(f"Wrote CSV: {csv_path}")
        return csv_path
    except Exception as e:
        print(f"Post-process (mem): CSV write failed: {e}")
        return None

def post_process_dump(dump_path: str, spec_path: str, title: str = "ILA Waveforms") -> None:
    try:
        signals = load_signal_spec_from_file(spec_path)
    except Exception as e:
        print(f"Post-process: failed to load signal spec '{spec_path}': {e}")
        return
    try:
        with open(dump_path, "r") as f:
            samples_words = json.load(f)
    except Exception as e:
        print(f"Post-process: failed to open dump '{dump_path}': {e}")
        return
    if not isinstance(samples_words, list):
        print("Post-process: dump JSON must be a list of samples.")
        return
    spec_depth = get_spec_capture_depth(spec_path)
    if spec_depth is not None:
        samples_words = samples_words[:spec_depth]
    combined_samples = build_samples_combined(samples_words, order="lsw_first")
    traces = extract_signal_traces(combined_samples, signals)
    # Derive CSV path from dump path
    base, ext = os.path.splitext(dump_path)
    csv_path = base + ".csv"
    try:
        write_csv(traces, signals, csv_path)
        print(f"Wrote CSV: {csv_path}")
    except Exception as e:
        print(f"Post-process: CSV write failed: {e}")
        print(f"Parsed {len(combined_samples)} samples across {len(signals)} signals, but CSV not written.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ILA capture utility")
    parser.add_argument("--dump-file", type=str, help="Path to write JSON dump of captured samples",default="output/samples.json")
    parser.add_argument("--timeout-ms", type=int, default=1000, help="Capture wait timeout in ms")
    default_spec = os.path.join(os.path.dirname(__file__), "spec.json")
    parser.add_argument("--spec", type=str, default=default_spec, help=f"Path to spec JSON (default: {default_spec})")
    args = parser.parse_args()

    # Load config from spec first (if present)
    if args.spec:
        apply_config_from_spec(args.spec)


    if args.dump_file:
        # Capture from hardware and process in-memory without writing JSON
        write_dword(0xFFFF_FFFF,0x0000_0000)
        disable_capture()
        print("disable_capture")
        reset_capture()
        enable_capture()
        print("enable_capture")
        ok = wait_for_capture(timeout=args.timeout_ms)
        print("wait_for_capture")
        disable_capture()
        if not ok:
            print("Capture timeout; no CSV written.")
            sys.exit(1)
        print("dump_capture")
        samples_words = dump_capture()
        # Derive CSV path from dump-file argument without writing JSON
        base, _ext = os.path.splitext(args.dump_file) if args.dump_file else ("output/samples", ".json")
        csv_path = base + ".csv"
        print("post_process_samples")
        # Process in-memory samples to CSV
        post_process_samples(samples_words, args.spec, order="lsw_first", csv_path=csv_path)
        print("done")
        write_dword(0xFFFF_FFFF,0x0000_0000)
