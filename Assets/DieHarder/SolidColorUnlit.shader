Shader "Custom/SolidColorUnlit"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        [Toggle] _IsLocal ("Is Local", Float) = 0
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        
        // Disable backface culling
        Cull Off

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float4 color : COLOR;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float _IsLocal;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                
                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(worldPos);
                OUT.color = IN.color;
                
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                
                // Discard solid red vertices if IsLocal is enabled
                if (_IsLocal > 0.5)
                {
                    float isRed   = step(0.9, IN.color.r) * step(IN.color.g, 0.1) * step(IN.color.b, 0.1);
                    float isGreen = step(0.9, IN.color.g) * step(IN.color.r, 0.1) * step(IN.color.b, 0.1);
                    float isBlue = step(0.9, IN.color.b) * step(IN.color.r, 0.1) * step(IN.color.g, 0.1);
                    float isHead = saturate(isRed + isGreen + isBlue);

                    // Check if vertex color is solid red (1, 0, 0)
                    if (isHead)
                    {
                        discard;
                    }
                }
                
                return _Color;
            }
            ENDHLSL
        }
    }
}
