Shader "Custom/URP/Shockwave"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BaseOpacity ("Base Opacity", Range(0, 1)) = 0.3
        _ProximityDistance ("Proximity Distance", Range(0, 10)) = 0.2
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        Pass
        {
            Name "ProximityReveal"
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
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
                float4 positionCS : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float fogFactor : TEXCOORD3;
                float4 color : COLOR;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float _BaseOpacity;
                float _ProximityDistance;
            CBUFFER_END
            
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS);
                
                OUT.positionCS = positionInputs.positionCS;
                OUT.screenPos = ComputeScreenPos(positionInputs.positionCS);
                OUT.positionWS = positionInputs.positionWS;
                OUT.normalWS = normalInputs.normalWS;
                OUT.fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
                OUT.color = IN.color;
                
                return OUT;
            }
            
            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                
                // Start with base color and opacity
                half4 color = _BaseColor;
                color.a = _BaseOpacity;
                
                // Sample the depth texture
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;
                
                #if UNITY_REVERSED_Z
                    float sceneDepth = SampleSceneDepth(screenUV);
                #else
                    float sceneDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(screenUV));
                #endif
                
                // Convert depths to linear eye space
                float sceneDepthLinear = LinearEyeDepth(sceneDepth, _ZBufferParams);
                float fragmentDepthLinear = LinearEyeDepth(IN.positionCS.z, _ZBufferParams);
                
                // Calculate distance between fragment and scene geometry
                float depthDifference = sceneDepthLinear - fragmentDepthLinear;
                
                // Multiply proximity distance by vertex color red channel
                float adjustedProximityDistance = _ProximityDistance * IN.color.r;
                
                // Hard cutoff: either add full opacity or nothing
                float proximityAlpha = (depthDifference > 0 && depthDifference <= adjustedProximityDistance) ? 1.0 : 0.0;
                
                // Add proximity effect to base opacity (clamped to max 1.0)
                color.a = saturate(color.a + proximityAlpha);
                
                // Apply fog
                color.rgb = MixFog(color.rgb, IN.fogFactor);
                
                return color;
            }
            ENDHLSL
        }
    }
    
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}