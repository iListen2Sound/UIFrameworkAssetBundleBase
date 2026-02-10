Shader "Custom/ToonUpwardCoverage_URP_FogCorrect"
{
    Properties
    {
        _HighlightColor ("Highlight Color", Color) = (1,1,1,1)
        _ShadeColor     ("Shade Color", Color)     = (0.2,0.2,0.2,1)

        _ToonSteps ("Toon Steps", Range(1,8)) = 3
        _Coverage  ("Upward Coverage", Range(0,1)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }

            ZWrite On
            Blend Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_instancing
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _HighlightColor;
                float4 _ShadeColor;
                float  _ToonSteps;
                float  _Coverage;
            CBUFFER_END

            Varyings vert (Attributes IN)
            {
                Varyings OUT;

                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.worldNormal = normalize(TransformObjectToWorldNormal(IN.normalOS));
                OUT.positionHCS = TransformWorldToHClip(worldPos);

                return OUT;
            }

            float4 frag (Varyings IN) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float3 N = normalize(IN.worldNormal);

                // ---- UPWARD NORMAL CLIPPING ----
                float upDot = dot(N, float3(0,1,0));

                // Coverage = 1 → no clipping
                // Coverage = 0 → only perfectly-up normals
                float threshold = lerp(1.0, -1.0, _Coverage);
                clip(upDot - threshold);

                // ---- MAIN LIGHT ----
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(N, mainLight.direction));

                // ---- TOON STEPS ----
                float toon = floor(NdotL * _ToonSteps) / max(1, (_ToonSteps - 1));
                float3 toonColor = lerp(
                    _ShadeColor.rgb,
                    _HighlightColor.rgb,
                    toon
                );

                float3 finalColor = toonColor * mainLight.color.rgb;

                // ---- APPLY FOG (URP) ----
                finalColor = MixFog(finalColor, ComputeFogFactor(IN.positionHCS.z));

                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}
