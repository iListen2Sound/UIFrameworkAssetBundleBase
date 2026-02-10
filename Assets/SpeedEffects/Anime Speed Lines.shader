Shader "Mirza/Anime Speed Lines"
{
    Properties
    {
        _MainTex ("Screen", 2D) = "black" {}
        _Colour("Colour", Color) = (1,1,1,1)
        _SpeedLinesTiling("Speed Lines Tiling", Float) = 200
        _SpeedLinesRadialScale("Speed Lines Radial Scale", Range(0, 10)) = 0.1
        _SpeedLinesPower("Speed Lines Power", Float) = 1
        _SpeedLinesRemap("Speed Lines Remap", Range(0, 1)) = 0.8
        _SpeedLinesAnimation("Speed Lines Animation", Float) = 3
        _MaskScale("Mask Scale", Range(0, 2)) = 1
        _MaskHardness("Mask Hardness", Range(0, 1)) = 0
        _MaskPower("Mask Power", Float) = 5
        [HideInInspector] _texcoord("", 2D) = "white" {}
        _RenderSpace ("Render Space", Float) = 1

    }

    SubShader
    {
        LOD 0
        ZTest Always
        Cull Off
        ZWrite Off

        Pass
        { 
            Blend SrcAlpha OneMinusSrcAlpha // Enable transparency blending

            CGPROGRAM

            #pragma vertex vert_img_custom
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            #include "UnityShaderVariables.cginc"

            struct appdata_img_custom
            {
                float4 vertex : POSITION;
                half2 texcoord : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f_img_custom
            {
                float4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1; // Screen-space position

                UNITY_VERTEX_OUTPUT_STEREO
            };

            uniform sampler2D _MainTex;
            uniform half4 _MainTex_TexelSize;
            uniform half4 _MainTex_ST;

            uniform float _SpeedLinesRadialScale;
            uniform float _SpeedLinesTiling;
            uniform float _SpeedLinesAnimation;
            uniform float _SpeedLinesPower;
            uniform float _SpeedLinesRemap;
            uniform float _MaskScale;
            uniform float _MaskHardness;
            uniform float _MaskPower;
            uniform float4 _Colour;
            uniform float _RenderSpace;

            float3 mod2D289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float2 mod2D289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float3 permute(float3 x) { return mod2D289(((x * 34.0) + 1.0) * x); }

            float snoise(float2 v)
            {
                const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
                float2 i = floor(v + dot(v, C.yy));
                float2 x0 = v - i + dot(i, C.xx);
                float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
                float4 x12 = x0.xyxy + C.xxzz;
                x12.xy -= i1;
                i = mod2D289(i);
                float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));
                float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
                m = m * m;
                m = m * m;
                float3 x = 2.0 * frac(p * C.www) - 1.0;
                float3 h = abs(x) - 0.5;
                float3 ox = floor(x + 0.5);
                float3 a0 = x - ox;
                m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
                float3 g;
                g.x = a0.x * x0.x + h.x * x0.y;
                g.yz = a0.yz * x12.xz + h.yz * x12.yw;
                return 130.0 * dot(m, g);
            }

            v2f_img_custom vert_img_custom(appdata_img_custom v) {
                v2f_img_custom o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f_img_custom, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;

                // Compute screen-space position
                o.screenPos = ComputeScreenPos(o.pos);

                return o;
            }

            half4 frag(v2f_img_custom i) : SV_Target {
                float2 uv;

                if (_RenderSpace > 0.5) {
                    // Screen space
                    float2 screenUV = i.screenPos.xy / i.screenPos.w;
                    screenUV.y = 1.0 - screenUV.y;
                    uv = screenUV;
                } else {
                    // Object space (fallback to regular UVs)
                    uv = i.uv;
                }

                // Centered UV for radial effect
                float2 CenteredUV = (uv - float2(0.5, 0.5));
                float2 polarUV = float2(length(CenteredUV) * _SpeedLinesRadialScale * 2.0,
                                        atan2(CenteredUV.x, CenteredUV.y) * (1.0 / 6.28318548202515) * _SpeedLinesTiling);
                float2 animatedUV = polarUV + float2(-_SpeedLinesAnimation * _Time.y, 0.0);
                float noise = snoise(animatedUV) * 0.5 + 0.5;

                float remap = _SpeedLinesRemap;
                float speedLines = saturate((pow(noise, _SpeedLinesPower) - remap) / (1.0 - remap));

                float2 maskUV = uv * 2.0 - 1.0;
                float scaled = _MaskScale;
                float hardness = lerp(0.0, scaled, _MaskHardness);
                float mask = pow(1.0 - saturate((length(maskUV) - scaled) / ((hardness - 0.001) - scaled)), _MaskPower);

                float lines = speedLines * mask;
                float3 colorRGB = _Colour.rgb;
                float colorA = _Colour.a;
                float alpha = lines * colorA;

                return float4(lines * colorRGB, alpha);
            }
            ENDCG 
        }
    }
    CustomEditor "ASEMaterialInspector"    
}
