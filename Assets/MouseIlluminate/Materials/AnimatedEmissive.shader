Shader "Custom/AnimatedEmissive"
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
		_AnimSpeed("Animation Speed", Range(0,4)) = .2
		_NoiseScale("Noise Scale", Range(0,2)) = .2
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
		half _ColorStrength, _EmissionStrength, _AnimSpeed, _NoiseScale;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
        // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

		// keijiro noise https://github.com/keijiro/NoiseShader/blob/master/Assets/HLSL/SimplexNoise3D.hlsl
		float3 mod289(float3 x) { return x - floor(x / 289.0) * 289.0; }
		float4 mod289(float4 x) { return x - floor(x / 289.0) * 289.0; }
		float4 permute(float4 x) { return mod289((x * 34.0 + 1.0) * x); }
		float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - r * 0.85373472095314; }

		float snoise(float3 v)
		{
			const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);

			// First corner
			float3 i = floor(v + dot(v, C.yyy));
			float3 x0 = v - i + dot(i, C.xxx);

			// Other corners
			float3 g = step(x0.yzx, x0.xyz);
			float3 l = 1.0 - g;
			float3 i1 = min(g.xyz, l.zxy);
			float3 i2 = max(g.xyz, l.zxy);

			// x1 = x0 - i1  + 1.0 * C.xxx;
			// x2 = x0 - i2  + 2.0 * C.xxx;
			// x3 = x0 - 1.0 + 3.0 * C.xxx;
			float3 x1 = x0 - i1 + C.xxx;
			float3 x2 = x0 - i2 + C.yyy;
			float3 x3 = x0 - 0.5;

			// Permutations
			i = mod289(i); // Avoid truncation effects in permutation
			float4 p =
				permute(permute(permute(i.z + float4(0.0, i1.z, i2.z, 1.0))
					+ i.y + float4(0.0, i1.y, i2.y, 1.0))
					+ i.x + float4(0.0, i1.x, i2.x, 1.0));

			// Gradients: 7x7 points over a square, mapped onto an octahedron.
			// The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
			float4 j = p - 49.0 * floor(p / 49.0);  // mod(p,7*7)

			float4 x_ = floor(j / 7.0);
			float4 y_ = floor(j - 7.0 * x_);  // mod(j,N)

			float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
			float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;

			float4 h = 1.0 - abs(x) - abs(y);

			float4 b0 = float4(x.xy, y.xy);
			float4 b1 = float4(x.zw, y.zw);

			//float4 s0 = float4(lessThan(b0, 0.0)) * 2.0 - 1.0;
			//float4 s1 = float4(lessThan(b1, 0.0)) * 2.0 - 1.0;
			float4 s0 = floor(b0) * 2.0 + 1.0;
			float4 s1 = floor(b1) * 2.0 + 1.0;
			float4 sh = -step(h, 0.0);

			float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
			float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

			float3 g0 = float3(a0.xy, h.x);
			float3 g1 = float3(a0.zw, h.y);
			float3 g2 = float3(a1.xy, h.z);
			float3 g3 = float3(a1.zw, h.w);

			// Normalise gradients
			float4 norm = taylorInvSqrt(float4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3)));
			g0 *= norm.x;
			g1 *= norm.y;
			g2 *= norm.z;
			g3 *= norm.w;

			// Mix final noise value
			float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
			m = m * m;
			m = m * m;

			float4 px = float4(dot(x0, g0), dot(x1, g1), dot(x2, g2), dot(x3, g3));
			return 42.0 * dot(m, px);
		}

		float3 brightnessContrast(float3 value, float brightness, float contrast)
		{
			return clamp((value - 0.5) * contrast + 0.5 + brightness, 0, 1);
		}

				
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			// grayscale
			fixed3 g = c.r + c.g + c.b * .3333;
			// emission
			fixed4 e = tex2D(_EmissionTex, IN.uv_EmissionTex) * _EmissionColor;

			// mask
			float m = snoise(float3(
				IN.worldPos.x + IN.worldPos.y, 
				IN.worldPos.z - IN.worldPos.y, 
				_Time.y * _AnimSpeed
			)*_NoiseScale)* .5 + .5;
			m = brightnessContrast(m, -.5, -3);
			

			// apply mask
			fixed4 lerpColor = lerp(fixed4(g, 1), c * _ColorStrength, m);
			fixed4 lerpEmission = lerp(fixed4(0,0,0,0), e * _EmissionStrength, m);


			o.Albedo = g;
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
