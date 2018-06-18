uniform vec4 uDiffuseColor;
uniform vec4 uAmbientColor;
uniform vec3 uSpecularColor;
uniform float uShininess;
uniform float uShadowStrength;
uniform vec3 uShadowColor;

out Vertex {
	vec4 color;
	vec3 SopSpacePos;
	vec3 SopSpaceNorm;
	vec2 texCoord0;
	flat int cameraIndex;
	flat int primIndex;
	flat mat4 instanceMat;
	flat mat4 worldMat;
	flat int vInstanceID;
}oVert;
 
in float primIndex;

void main()
{
	// LTH: TDDeform skipped here, will mimic in geo shader
	vec4 SopSpacePos = vec4(P, 1.0);
	gl_Position = SopSpacePos;

	oVert.instanceMat = TDInstanceMat();
	oVert.worldMat = uTDMats[TDCameraIndex()].world;
	oVert.vInstanceID = TDInstanceID();

	// This is here to ensure we only execute lighting etc. code
	// when we need it. If picking is active we don't need this, so
	// this entire block of code will be ommited from the compile.
	// The TD_PICKING_ACTIVE define will be set automatically when
	// picking is active.
#ifndef TD_PICKING_ACTIVE

	{ // Avoid duplicate variable defs
		vec3 texcoord = TDInstanceTexCoord(uv[0]);
		oVert.texCoord0.st = texcoord.st;
	}
	int cameraIndex = TDCameraIndex();
	oVert.cameraIndex = cameraIndex;
	oVert.SopSpacePos.xyz = SopSpacePos.xyz;
	oVert.color = TDInstanceColor(Cd);

	vec3 SopSpaceNorm = normalize(N);
	oVert.SopSpaceNorm = SopSpaceNorm;
	oVert.primIndex = int(primIndex);

#else // TD_PICKING_ACTIVE

	// This will automatically write out the nessessary values
	// for this shader to work with picking.
	// See the documentation if you want to write custom values for picking.
	TDWritePickingValues();

#endif // TD_PICKING_ACTIVE
}
