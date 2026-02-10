    Shader "Custom/ToonShader"
    {
        Properties
        {
            _MainTex ("Texture", 2D) = "white" {}
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

                    OUT.positionHCS = TransformWorldToHClip(worldPos);
                    return OUT;
                }

                float4 frag(Varyings IN) : SV_Target
                {
                    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                    Light mainLight = GetMainLight();
                    float NdotL = saturate(dot(IN.worldNormal, mainLight.direction));

                    float toonBrightness = floor(NdotL * _ToonSteps) / (_ToonSteps - 1);
                    float3 litColor = lerp(float3(0.2, 0.2, 0.2), 1.0, toonBrightness);

                    float4 textureColor = tex2D(_MainTex, IN.uv);
                    float3 finalColor = textureColor.rgb * litColor * mainLight.color.rgb * 2;

                    return float4(finalColor, 1.0);
                }
                ENDHLSL
            }
        }
    }
