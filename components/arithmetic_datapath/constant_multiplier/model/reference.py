"""Independent arbitrary-precision oracle; no generator/DAG imports."""


def evaluate(bits, config):
    w = config["INPUT_WIDTH"]
    x = bits & ((1 << w) - 1)
    if config["INPUT_SIGNED"] and x & (1 << (w - 1)):
        x -= 1 << w
    p = x * int(config["COEFF"])
    shift = config["SHIFT_RIGHT"]
    if config["ROUND_MODE"] == "FLOOR":
        r = p // (1 << shift)
    elif config["ROUND_MODE"] == "TOWARD_ZERO":
        r = (abs(p) >> shift) * (-1 if p < 0 else 1)
    else:
        magnitude, residue = divmod(abs(p), 1 << shift)
        if residue * 2 > (1 << shift) or (residue * 2 == (1 << shift) and magnitude % 2):
            magnitude += 1
        r = magnitude * (-1 if p < 0 else 1)
    ow, signed = config["OUTPUT_WIDTH"], config["OUTPUT_SIGNED"]
    low = -(1 << (ow - 1)) if signed else 0
    high = (1 << (ow - int(signed))) - 1
    overflow = r < low or r > high
    if config["OUTPUT_MODE"] == "FULL":
        # Independently derive the minimal FULL format using bit_length,
        # rather than trusting the generator's interval-search implementation.
        xmin = -(1 << (w - 1)) if config["INPUT_SIGNED"] else 0
        xmax = (1 << (w - int(config["INPUT_SIGNED"]))) - 1
        a, b = sorted((xmin * int(config["COEFF"]), xmax * int(config["COEFF"])))
        expected_signed = config["INPUT_SIGNED"] or int(config["COEFF"]) < 0
        expected_width = max(1, b.bit_length())
        if expected_signed:
            expected_width = max(max(0, b).bit_length() + 1, (~a).bit_length() + 1 if a < 0 else 1)
        if ow != expected_width or signed != expected_signed or overflow:
            raise ValueError("FULL output format is not exact and minimal")
        overflow = False
    if config["OVERFLOW_MODE"] == "SATURATE":
        r = max(low, min(high, r))
    return r & ((1 << ow) - 1), int(overflow)
