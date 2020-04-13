Shader "Custom/SphericalMask"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		_ColorStrength("Color Strength", Range(0,4)) = 1
        _EmissionTex ("Emission (RGB)", 2D) = "white" {}
        _EmissionColor ("Emission Color", Color) = (1,1,1,1)
		_EmissionStrength("Emission Strength", Range(0,4)) = 1
		_BumpMap("Bumpmap", 2D) = "bump" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
		//_Position("World Position", Vector) = (0,0,0)
		//_Radius("Sphere Radius", Range(0,100)) = 1
		//_Softness("Sphere Softness", Range(0,100)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex, _EmissionTex, _BumpMap;

        struct Input
        {
            float2 uv_MainTex;
            float2 uv_EmissionTex;
			float2 uv_BumpMap;
			float3 worldPos;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color, _EmissionColor;
		half _ColorStrength, _EmissionStrength;

		// Spherical Mask
		uniform float4 SphericalMask_Position;
		uniform half SphericalMask_Radius;
		uniform half SphericalMask_Softness;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			// grayscale
			fixed3 g = c.r + c.g + c.b * .3333;
			// emission
			fixed4 e = tex2D(_EmissionTex, IN.uv_EmissionTex) * _EmissionColor;

			half d = distance(SphericalMask_Position, IN.worldPos);
			half sum = saturate((d - SphericalMask_Radius) / - SphericalMask_Softness);
			fixed4 lerpColor = lerp(fixed4(g, 1), c * _ColorStrength, sum);
			fixed4 lerpEmission = lerp(fixed4(0,0,0,0), e * _EmissionStrength, sum);


			o.Albedo = lerpColor;
			o.Emission = lerpEmission;
            // Metallic and smoothness come from slider variables
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
			o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
