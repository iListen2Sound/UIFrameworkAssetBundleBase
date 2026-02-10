Shader "Custom/Ghost"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1,1,1,1)
        _Opacity ("Inside Opacity", Range(0,1)) = 0.4
        _FresnelPower ("Fresnel Power", Range(0.1, 10)) = 1.2

        _HeadOpacity ("Head Vertex Opacity", Range(0,1)) = 1
        _BodyOpacity ("Body Opacity", Range(0,1)) = 1

        _Inflate ("Vertex Inflate Amount", Range(0,0.1)) = 0

        [Toggle] _IsLocal ("Is Local", Float) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        Cull Back
        Blend SrcAlpha OneMinusSrcAlpha

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
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float4 color : COLOR;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float _Opacity;
                float _FresnelPower;
                float _HeadOpacity;
                float _BodyOpacity;
                float _Inflate;
                float _IsLocal;
            CBUFFER_END

            sampler2D _MainTex;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                float3 inflatedPosOS = IN.positionOS.xyz + IN.normalOS * _Inflate;

                float3 worldPos = TransformObjectToWorld(inflatedPosOS);
                float3 worldNormal = TransformObjectToWorldNormal(IN.normalOS);

                OUT.worldPos = worldPos;
                OUT.worldNormal = normalize(worldNormal);
                OUT.uv = IN.uv;
                OUT.color = IN.color;

                OUT.positionHCS = TransformWorldToHClip(worldPos);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float4 texColor = tex2D(_MainTex, IN.uv);
                float4 finalColor = texColor * _Color;

                float3 viewDir = normalize(_WorldSpaceCameraPos - IN.worldPos);
                float fresnel = 1.0 - saturate(dot(IN.worldNormal, viewDir));
                fresnel = pow(fresnel, _FresnelPower);

                float rimMask = step(0.5, fresnel);
                float baseAlpha = lerp(_Opacity, 1.0, rimMask);

                if (_IsLocal > 0.5)
                {
                    float isRed   = step(0.9, IN.color.r) * step(IN.color.g, 0.1) * step(IN.color.b, 0.1);
                    float isGreen = step(0.9, IN.color.g) * step(IN.color.r, 0.1) * step(IN.color.b, 0.1);
                    float isBlue = step(0.9, IN.color.b) * step(IN.color.r, 0.1) * step(IN.color.g, 0.1);

                    float isHead = saturate(isRed + isGreen + isBlue);

                    if (isHead)
                    {
                        discard;
                    }
                }

                finalColor.a = baseAlpha * _BodyOpacity;

                return finalColor;
            }
            ENDHLSL
        }
    }
}
