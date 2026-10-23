// SHA-256 in pure Pawn. open.mp's SHA256_Hash/SHA256_PassHash log an
// "unsafe hashing" warning on every call, so password hashing uses this.

static const gSha256K[64] =
{
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static Sha256Rotr(x, n)
{
	return (x >>> n) | (x << (32 - n));
}

// Byte `i` of the padded message for an input of `len` bytes
static Sha256Byte(const input[], len, total, i)
{
	if (i < len) return input[i] & 0xFF;
	if (i == len) return 0x80;
	if (i >= total - 4) return ((len * 8) >>> ((total - 1 - i) * 8)) & 0xFF;
	return 0;
}

// Writes the lowercase hex SHA-256 digest of the string `input` to `out`.
stock Sha256(const input[], out[65])
{
	static const hex[] = "0123456789abcdef";
	new h[8] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
	new w[64], len = strlen(input);
	new total = ((len + 9 + 63) / 64) * 64;

	for (new block = 0; block < total; block += 64)
	{
		for (new t = 0; t < 16; t++)
		{
			new p = block + t * 4;
			w[t] = (Sha256Byte(input, len, total, p) << 24) | (Sha256Byte(input, len, total, p + 1) << 16)
				| (Sha256Byte(input, len, total, p + 2) << 8) | Sha256Byte(input, len, total, p + 3);
		}
		for (new t = 16; t < 64; t++)
		{
			new s0 = Sha256Rotr(w[t - 15], 7) ^ Sha256Rotr(w[t - 15], 18) ^ (w[t - 15] >>> 3);
			new s1 = Sha256Rotr(w[t - 2], 17) ^ Sha256Rotr(w[t - 2], 19) ^ (w[t - 2] >>> 10);
			w[t] = w[t - 16] + s0 + w[t - 7] + s1;
		}

		new a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], k = h[7];
		for (new t = 0; t < 64; t++)
		{
			new t1 = k + (Sha256Rotr(e, 6) ^ Sha256Rotr(e, 11) ^ Sha256Rotr(e, 25)) + ((e & f) ^ (~e & g)) + gSha256K[t] + w[t];
			new t2 = (Sha256Rotr(a, 2) ^ Sha256Rotr(a, 13) ^ Sha256Rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
			k = g;
			g = f;
			f = e;
			e = d + t1;
			d = c;
			c = b;
			b = a;
			a = t1 + t2;
		}
		h[0] += a; h[1] += b; h[2] += c; h[3] += d;
		h[4] += e; h[5] += f; h[6] += g; h[7] += k;
	}

	for (new i = 0; i < 64; i++)
	{
		out[i] = hex[(h[i / 8] >>> ((7 - i % 8) * 4)) & 0xF];
	}
	out[64] = '\0';
}
