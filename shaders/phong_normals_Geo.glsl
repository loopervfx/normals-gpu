layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

uniform int uMode;

uniform samplerBuffer sVertexByPrim;
uniform samplerBuffer sPointOffset;
uniform samplerBuffer sVertexByPoint;
uniform samplerBuffer sPositionByPrim;

uniform sampler2D sTwist;
uniform vec3 uTwistAxis;
uniform vec3 uSize;
uniform vec3 uMin;

in Vertex {
	vec4 color;
	vec3 SopSpacePos;
	vec3 SopSpaceNorm;
	vec2 texCoord0;
	flat int cameraIndex;
	flat int primIndex;
	flat mat4 instanceMat;
	flat mat4 worldMat;
	flat int vInstanceID;
}iVert[];

out Vertex {
	vec4 color;
	vec3 worldSpacePos;
	vec3 worldSpaceNorm;
	flat int cameraIndex;
}oVert;

// maximum triangle adjacency
// for smooth vertex normals
const int maxAdj = 12;

// init vars
int primVertIndex[3] = int[3] ( 0, 0, 0 );
int primsAdjIndex[3] = int[3] ( 0, 0, 0 );
int pointIndex[3] = int[3] ( 0, 0, 0 );

vec3 primsAdjPos[3] = vec3[3] ( vec3(0.0), vec3(0.0), vec3(0.0) );
vec3 worldFacePos[3] = vec3[3] ( vec3(0.0), vec3(0.0), vec3(0.0) );

vec3 faceAdjNorm[maxAdj];
vec3 faceNorm = vec3(0.0);

// mimic TDDeform() by multiplying 4x4 matrices from vertex stage
vec3 TDDeform(vec3 vector, int i) {
	return vec3(iVert[i].worldMat * iVert[i].instanceMat * vec4(vector, 1.0));
}

// mimic TDDeformNorm() by multiplying 3x3 matrices from vertex stage
vec3 TDDeformNorm(vec3 vector, int i) {
	return vec3(mat3(iVert[i].worldMat) * mat3(iVert[i].instanceMat) * vector);
}

// twist matrix generation and multiplication
// uMin & uSize are used to generate UV coord
vec3 twistDeform(vec3 vector, int i) {
	vec2 texCoord = vec2(0.0);
	texCoord.s = length( (vector - uMin) / uSize * uTwistAxis);
	texCoord.t = float(iVert[i].vInstanceID)/textureSize(sTwist,0).s;
	float twistRadians = texture(sTwist, texCoord).r;
	return TDRotateOnAxis(twistRadians, uTwistAxis) * vector;
}

void main() {

	// for the 3 vertices in this triangle prim
	for(int i = 0; i < 3; i++) {

		switch (uMode)
		{
			default:
			
				/* DEFAULT NORMALS */
				oVert.worldSpaceNorm = TDDeformNorm(iVert[i].SopSpaceNorm, i);
				//oVert.worldSpaceNorm = TDDeformNorm(twistDeform(iVert[i].SopSpaceNorm, i), i);
				//
				// twistDeform is disabled here to help illustrate "default" TD normal deformation.
				break;

			case 1: 

				/* FACETED NORMALS */

				// Twist matrix multiply with triangle positions
				worldFacePos[0] = TDDeform(twistDeform(iVert[0].SopSpacePos, i), i);
				worldFacePos[1] = TDDeform(twistDeform(iVert[1].SopSpacePos, i), i);
				worldFacePos[2] = TDDeform(twistDeform(iVert[2].SopSpacePos, i), i);

				// To compute the face normal of a triangle, select one vertex, 
				// compute the vectors from that vertex to the other two vertices,
				// then compute the cross product of those two vectors.
				// Normalize the result to get the unit-length facet normal.
				//
				// https://www.opengl.org/archives/resources/code/samples/sig99/advanced99/notes/node15.html

				faceNorm = normalize(cross( worldFacePos[0] - worldFacePos[1],
								worldFacePos[0] - worldFacePos[2] ));
				oVert.worldSpaceNorm = faceNorm;

				break;

			case 2: 

				/* SMOOTH VERTEX NORMALS */

				// Face normals and Vertex normals are both naively calculated here
				// in a single shader pass using a nested loop for adjacent triangles.

				// A two pass method would be more efficient, but perhaps convoluted 
				// within TouchDesigner's standard render pipeline for MATs / Materials.

				// fetch array indices
				primVertIndex[i] = (iVert[i].primIndex * 3) + i;
				pointIndex[i] = int(texelFetchBuffer(sVertexByPrim, primVertIndex[i]).r);

				// fetch point offset indices
				int pointOffsetStart = int(texelFetchBuffer(sPointOffset, pointIndex[i]).r);
				int pointOffsetEnd = int(texelFetchBuffer(sPointOffset, pointIndex[i]+1).r);

				// set range for adjacency loop
				int numPrims = pointOffsetEnd - pointOffsetStart;

				// for every triangle prim adjacent to this vertex
				for(int j = 0; j < numPrims; j++) {

					// for the 3 vertices in this adjacent triangle prim
					for(int k = 0; k < 3; k++) {

						// fetch position index with point offset index
						primsAdjIndex[k] = int(texelFetchBuffer(sVertexByPoint, pointOffsetStart+j).r * 3 + k);

						// fetch position vector with adjacent triangle prim index
						primsAdjPos[k] = vec3(texelFetchBuffer(sPositionByPrim, primsAdjIndex[k]));

						// Twist matrix multiply with adjacent triangle positions & TDDeform
						primsAdjPos[k] = TDDeform(twistDeform(primsAdjPos[k], i), i);

					}

					// use position vectors to calculate face normal for this adjacent triangle
					faceAdjNorm[j] = normalize(cross( primsAdjPos[0] - primsAdjPos[1],
										primsAdjPos[0] - primsAdjPos[2] ));
				}
				// init vertex normal vector
				vec3 vertexNorm = vec3(0.0);

				// summation of adjacent face normals
				for(int n = 0; n < numPrims; n++)
				 	vertexNorm += faceAdjNorm[n];

				// normalize summation to get mean/average of face normals
				// this is the resulting vertex normal
				oVert.worldSpaceNorm = normalize(vertexNorm);

				break;

		}

		// set output attributes for fragment shader
		oVert.color = iVert[i].color;
		oVert.cameraIndex = iVert[i].cameraIndex;

		// Twist matrix multiply with world position
		oVert.worldSpacePos = TDDeform(twistDeform(gl_in[i].gl_Position.xyz, i), i);

		// World space -> camera/screen space
		gl_Position = TDWorldToProj(oVert.worldSpacePos, iVert[i].cameraIndex);

		EmitVertex();
	}
	EndPrimitive();
}
