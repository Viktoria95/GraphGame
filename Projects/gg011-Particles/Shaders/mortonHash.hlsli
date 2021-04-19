

uint mortonHash(float3 pos) {
	//uint x = (pos.x + boundarySide) / (2.0f * boundarySide) * 1023.0;
	//uint z = (pos.z + boundarySide) / (2.0f * boundarySide) * 1023.0;
	//uint y = (pos.y - boundaryBottom) / (boundaryBottom + boundaryTop) * 1023.0;

	const float maxIndex = 1023.9999;
	//const float maxIndex = 15.0;
	uint x = (pos.x + boundarySide) / (2.0f * boundarySide) * maxIndex;
	uint z = (pos.z + boundarySide) / (2.0f * boundarySide) * maxIndex;
	uint y = (pos.y - boundaryBottom) / (boundaryBottom + boundaryTop) * maxIndex;
	//if (pos.z < 100000.0) {
		//x = y = z = 0;
	//}
	

//	uint hash = 0;
//	uint i;
//	for (i = 0; i < 10; ++i)
//	{
//		hash |= ((x & (1 << i)) << 2 * i) | ((z & (1 << i)) << (2 * i + 1)) | ((y & (1 << i)) << (2 * i + 2));
//	}
//	return hash;

	x = (x | (x << 10)) & 0x000f801f;  // 000000000011111000000000011111
	x = (x | (x << 6))  & 0x03038607;  // 000011000000111000011000000111
	x = (x | (x << 4))  & 0x03218643;  // 000011001000011000011001000011
	x = (x | (x << 2))  & 0x09249249;  // 001001001001001001001001001001
	z = (z | (z << 10)) & 0x000f801f;  // 000000000011111000000000011111
	z = (z | (z << 6))  & 0x03038607;  // 000011000000111000011000000111
	z = (z | (z << 4))  & 0x03218643;  // 000011001000011000011001000011
	z = (z | (z << 2))  & 0x09249249;  // 001001001001001001001001001001
	y = (y | (y << 10)) & 0x000f801f;  // 000000000011111000000000011111
	y = (y | (y << 6))  & 0x03038607;  // 000011000000111000011000000111
	y = (y | (y << 4))  & 0x03218643;  // 000011001000011000011001000011
	y = (y | (y << 2))  & 0x09249249;  // 001001001001001001001001001001

	return x | (z<<1) | (y<<2);
}

