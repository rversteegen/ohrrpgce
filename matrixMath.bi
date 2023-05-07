'OHRRPGCE - Matrix routines
'(C) Copyright 1997-2022 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.
'
'exposes functions for creating 3x3 2d transformation matrices, multiplying them, and multiplying 3d vectors (x,y,w) against them

#IFNDEF MATRIX_MATH_BI
#DEFINE MATRIX_MATH_BI

#include "config.bi"
#include "util.bi"  'Contains actual Float2 type

' TYPE Float2
'   x as single
'   y as single
' END TYPE

TYPE Float3
  x as single
  y as single
  w as single
END TYPE

TYPE Float3x3
  _11 as single : _12 as single : _13 as single
  _21 as single : _22 as single : _23 as single
  _31 as single : _32 as single : _33 as single
END TYPE

'Describes an affine transformation if it's a parallelogram
UNION Quad
	TYPE
		bottomleft as Float2
		topleft as Float2
		topright as Float2
		bottomright as Float2
	END TYPE
	vertices(3) as Float2
END UNION

EXTERN "C"

'transforms from local coordinates to the specified scale, rotation (clockwise by "angle"), and translation; assembled in manner of Scale-Rotate-Transform (SRT)
DECLARE SUB scaleRotateMatrix( byval pMatrixOut as float3x3 ptr, byval angle as single, byref scale as float2, byref position as float2 )

'multiplies matrices together; pMatrixOut = A x B
DECLARE SUB matrixMultiply( byval pMatrixOut as float3x3 ptr, byref A as float3x3, byref B as float3x3 )

'Transforms all the vectors in pVec2ArrayIn into pVec2ArrayOut by an affine transform matrix
'(i.e. only the top-left 2x3 elements are used).
'pVec2ArrayIn == pVec2ArrayOut is allowed.
'The strides can be given if the float2's are embedded in another struct, e.g. VertexPTC.
DECLARE SUB vec2Transform( byval pVec2ArrayOut as float2 ptr, byval szStrideOut as integer = sizeof(float2), byval pVec2ArrayIn as float2 ptr, byval szStrideIn as integer = sizeof(float2), byval nVectors as integer, byref transformMatrix as float3x3 )

'Treat a Quad as an affine transformation matrix (ignores its bottomright vertext).
'vec2 are U,V coords, the range [0,1] will map onto the area of the Quad.
DECLARE FUNCTION vec2QuadTransform( byval vec2 as Float2, byref transform as Quad ) as Float2

'Transforms all the vectors in pVec3ArrayIn into pVec3ArrayOut by `transformMatrix`
'DECLARE SUB vec3Transform( byval pVec3ArrayOut as float3 ptr, byval destSize as integer, byval pVec3ArrayIn as float3 ptr, byval srcSize as integer, byref transformMatrix as float3x3 )

'Generates the local coordinate corners (relative a center) of a quad, to be used
'as input to vec2Transform/vec3Transform
DECLARE SUB vec2GenerateCorners( byval pVecArrayOut as Float2 ptr, byval destSize as integer, byref size as Float2, byref center as Float2)
'DECLARE SUB vec3GenerateCorners( byval pVecArrayOut as Float3 ptr, byval destSize as integer, byref size as Float3, byref center as Float3)

'Calculate Euclidean distance between two points
DECLARE FUNCTION vec2Distance( byref p1 as Float2, byref p2 as Float2 ) as double
DECLARE FUNCTION vec3Distance( byref p1 as Float3, byref p2 as Float3 ) as double

END EXTERN

#ENDIF
