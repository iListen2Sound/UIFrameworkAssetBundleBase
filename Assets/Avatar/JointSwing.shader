Shader "Custom/JointSwing"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SwingAmplitude ("Swing Amplitude", Float) = 0.2
        _SwingSpeed ("Swing Speed", Float) = 2.0
        _PivotOffset ("Pivot Offset", Vector) = (0,0,0,0)
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
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float _SwingAmplitude;
                float _SwingSpeed;
                float4 _PivotOffset;
            CBUFFER_END

            sampler2D _MainTex;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                float3 pivot = TransformObjectToWorld(_PivotOffset.xyz);

                float3 localOffset = worldPos - pivot;

                // Simulate swinging using sine wave based on time and offset
                float swing = sin(_Time.y * _SwingSpeed + localOffset.y * 2.0) * _SwingAmplitude;

                // Apply swing around pivot in XZ plane
                float3 swingOffset = float3(swing * localOffset.z, 0, -swing * localOffset.x);
                worldPos += swingOffset;

                OUT.positionHCS = TransformWorldToHClip(worldPos);
                OUT.uv = IN.uv;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                return tex2D(_MainTex, IN.uv);
            }
            ENDHLSL
        }
    }
}
