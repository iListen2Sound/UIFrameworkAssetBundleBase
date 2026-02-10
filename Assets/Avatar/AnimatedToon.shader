Shader "Custom/AnimatedToon"
{
    Properties
    {
        _MainTex ("Spritesheet", 2D) = "white" {}
        _Columns ("Columns", Int) = 5
        _Rows ("Rows", Int) = 5
        _Speed ("Frames Per Second", Float) = 24.0
        _ToonSteps("Toon Steps", Range(1,8)) = 3
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float2 uv : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float _ToonSteps;
            CBUFFER_END

            sampler2D _MainTex;
            int _Columns;
            int _Rows;
            float _Speed;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(IN.normalOS);

                OUT.worldPos = worldPos;
                OUT.worldNormal = normalize(worldNormal);
                OUT.uv = IN.uv;

                // VR-correct projection
                OUT.positionHCS = TransformWorldToHClip(worldPos);
                return OUT;
            }
            
            float4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                // --- Lighting ---
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(IN.worldNormal, mainLight.direction));

                // Quantize light for toon shading
                float toonBrightness = floor(NdotL * _ToonSteps) / (_ToonSteps - 1);
                float3 litColor = lerp(float3(0.2, 0.2, 0.2), 1.0, toonBrightness);

                float totalFrames = _Columns * _Rows;
                float time = _Time.y * _Speed;
                float frame = floor(fmod(time, totalFrames));

                float col = fmod(frame, _Columns);
                float row = floor(frame / _Columns);

                float2 uv = IN.uv;
                uv.x = (uv.x + col) / _Columns;
                uv.y = (uv.y + (_Rows - 1 - row)) / _Rows;
                
                float4 textureColor = tex2D(_MainTex, uv);
                float3 finalColor = textureColor.rgb * litColor * mainLight.color.rgb * 2;
                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}