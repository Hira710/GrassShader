Shader "Dreamo/GrassMult2"
{
    Properties
    {
        [Header(GrassColor)]
        _GrassColorTex ("Grass Color", 2D) = "white" {}

        [Header(Overwhelm)]
        _OverwhelmTex ("Overwhelm Map", 2D) = "white" {}
        _OverwhelmStrength ("Overwhelm Strength", Range(0, 1)) = 0.5

        [Header(Wind)]
        _WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.02, 0.02, 0, 0)
        _WindStrength("Wind Strength", Float) = 1

        [Header(Width Height Forward)]
        _BladeWidth("Blade Width", Float) = 0.05
        _BladeWidthRandom("Blade Width Random", Float) = 0.02
        _BladeHeight("Blade Height", Float) = 0.5
        _BladeHeightRandom("Blade Height Random", Float) = 0.3
        _BladeForward("Blade Forward Amount", Float) = 0.38
		_BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
        _OffsetX("Offset X",Range(0,1)) = 0.1
        _OffsetZ("Offset Z",Range(0,1)) = 0.1

        [Header(Tessellation)]
        _TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1

        [Header(Other)]
        _FacingRotateTex ("Facing Rotate Map", 2D) = "black" {}
    }

	CGINCLUDE
	#include "UnityCG.cginc"
    #include "UnlitGrassShaderTessellation.cginc"

    #define BLADE_SEGMENTS 3

    sampler2D _GrassColorTex;
    float4 _GrassColorTex_ST;

    sampler2D _OverwhelmTex;
    float4 _OverwhelmTex_ST;
    float _OverwhelmStrength;

    sampler2D _WindDistortionMap;
    float4 _WindDistortionMap_ST;
    float2 _WindFrequency;
    float _WindStrength;

    float _BladeHeight;
    float _BladeHeightRandom;	
    float _BladeWidth;
    float _BladeWidthRandom;
    float _BladeForward;
	float _BladeCurve;
    float _OffsetX;
    float _OffsetZ;

    sampler2D _FacingRotateTex;
    float4 _FacingRotateTex_ST;

	float rand(float3 co)
	{
		return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
	}

	float3x3 AngleAxis3x3(float angle, float3 axis)
	{
		float c, s;
		sincos(angle, s, c);

		float t = 1 - c;
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return float3x3(
			t * x * x + c, t * x * y - s * z, t * x * z + s * y,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c
			);
	}

    struct geometryOutput
    {
	    float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
        float3 normal : NORMAL;

        float4 grassColor : COLOR;
    };

    geometryOutput VertexOutput(float3 pos, float2  grassUV,float4 grassColor, float3 normal)
    {
	    geometryOutput o;

	    o.pos = UnityObjectToClipPos(pos);
        o.uv = grassUV;

        o.grassColor = grassColor;
        o.normal = UnityObjectToWorldNormal(normal);
	    return o;
    }

    geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 grassUV,float4 grassColor, float3x3 transformMatrix)
    {
	    float3 tangentPoint = float3(width, forward, height);
        float3 tangentNormal = normalize(float3(0, -1, forward));
        float3 localNormal = mul(transformMatrix, tangentNormal);
	    float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);

	    return VertexOutput(localPosition, grassUV,grassColor,localNormal);
    }

    //[maxvertexcount(3)] 
    [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
    void geo(triangle vertexOutput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
    {
        float3 vPos = IN[0].pos;
        float3 vNormal = IN[0].normal;
        float4 vTangent = IN[0].tangent;
        float3 vBinormal = cross(vNormal, vTangent) * vTangent.w;

        float3x3 tangentToLocal = float3x3(
	        vTangent.x, vBinormal.x, vNormal.x,
	        vTangent.y, vBinormal.y, vNormal.y,
	        vTangent.z, vBinormal.z, vNormal.z
	    );

//grass color
        float4 groundUV = IN[0].groundUV;
        float2 grassTransUV = TRANSFORM_TEX(groundUV, _GrassColorTex);
        float4 grassColor = tex2Dlod(_GrassColorTex, float4(grassTransUV, 0, 0));

//overwhelm
        float2 overwhelmTransUV = TRANSFORM_TEX(groundUV, _OverwhelmTex);
        float4 overwhelmColor = tex2Dlod(_OverwhelmTex, float4(overwhelmTransUV, 0, 0));
        float4 _touchPoint = float4(overwhelmColor.g + vPos.x,0,overwhelmColor.b+vPos.z,0.6);

        float3 faceToTouchPoint = normalize(vPos - _touchPoint);
        if(faceToTouchPoint.x==0){
             faceToTouchPoint.x = 0.001;
        }
        float facingRad = atan(faceToTouchPoint.z/faceToTouchPoint.x) + UNITY_HALF_PI;

        if (vPos.x > _touchPoint.x){
            facingRad += UNITY_PI;
        }
        float3x3 faceToTouchMatrix = AngleAxis3x3(facingRad, float3(0, 0, 1));
        float3x3 faceToTouchTransMatrix = mul(tangentToLocal, faceToTouchMatrix);

//Random facing rotate
        float2 rotateTransUV = TRANSFORM_TEX(groundUV, _FacingRotateTex);
        float4 rotateColor = tex2Dlod(_FacingRotateTex, float4(rotateTransUV, 0, 0));
        float3x3 facingRotationMatrix = AngleAxis3x3(rotateColor.r, float3(0, 0, 1));
        float3x3 facingRotationTransMatrix = mul(faceToTouchTransMatrix, facingRotationMatrix);



//Wind
        float2 windUV = vPos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
        float2 windSample = (tex2Dlod(_WindDistortionMap, float4(windUV, 0, 0)).xy * 2 - 1) * _WindStrength;
        float3 wind = normalize(float3(windSample.x, windSample.y, 0));
        float3x3 windRotationMatrix = AngleAxis3x3(UNITY_PI * windSample, wind);
        float3x3 windRotationTransMatrix = mul(facingRotationTransMatrix,windRotationMatrix);

//height and width

        float height = (rand(vPos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
        float width = (rand(vPos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
        float forward = rand(vPos.yyz) * _BladeForward;


//pos offset
        float offsetX = rand(vPos.zyx) * _OffsetX;
        float offsetZ = rand(vPos.zxy) * _OffsetZ;
        vPos.x += offsetX;
        vPos.z += offsetZ;

        for (int i = 0; i < BLADE_SEGMENTS; i++)
        {
	        float t = i / (float)BLADE_SEGMENTS;
            float segmentHeight = height * t;
            float segmentWidth = width * (1 - t);
            float segmentForward = pow(t, _BladeCurve) * forward;

//Overwhelm by color map
        float overwhelmRad = overwhelmColor.r * UNITY_HALF_PI * _OverwhelmStrength * t;
        float3x3 overwhelmRotationMatrix = AngleAxis3x3(overwhelmRad, float3(1, 0, 0));
        float3x3 overwhelmRotationTransMatrix = mul(windRotationTransMatrix, overwhelmRotationMatrix);

        triStream.Append(GenerateGrassVertex(vPos, segmentWidth, segmentHeight,segmentForward, float2(0, t),grassColor, overwhelmRotationTransMatrix));
        triStream.Append(GenerateGrassVertex(vPos, -segmentWidth, segmentHeight,segmentForward, float2(1, t),grassColor, overwhelmRotationTransMatrix));
        }

        float overwhelmRad = overwhelmColor.r * UNITY_HALF_PI * _OverwhelmStrength;
        float3x3 overwhelmRotationMatrix = AngleAxis3x3(overwhelmRad, float3(1, 0, 0));
        float3x3 overwhelmRotationTransMatrix = mul(windRotationTransMatrix, overwhelmRotationMatrix);
        triStream.Append(GenerateGrassVertex(vPos, 0, height,forward, float2(0.5, 1),grassColor, overwhelmRotationTransMatrix));
    }

	ENDCG

    SubShader
    {
		Cull Off

        Pass
        {
			Tags
			{
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
			}

            CGPROGRAM
            #pragma vertex vert

            #pragma fragment frag
			#pragma target 4.6
            #pragma multi_compile_fwdbase
            #pragma geometry geo

            #pragma hull hull
            #pragma domain domain


			//float4 _TopColor;
			//float4 _BottomColor;

			float4 frag (geometryOutput i, fixed facing : VFACE) : SV_Target
            {
                float4 baseColor = i.grassColor;
                float4 topColor = baseColor * 8;
                
                float4 col = lerp(baseColor, topColor, i.uv.y);
                return col;
            }
            ENDCG
        }
    }
}