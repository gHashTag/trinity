import{a$ as t}from"./QueenComb-Cd0IuFn3.js";import"./index-DnJy9pD2.js";import"./react--6nd5XBq.js";import"./motion-CvAcPNoJ.js";import"./router-CmS70aoX.js";const e="glowMapMergeVertexShader",r=`attribute position: vec2f;varying vUV: vec2f;
#define CUSTOM_VERTEX_DEFINITIONS
@vertex
fn main(input : VertexInputs)->FragmentInputs {const madd: vec2f= vec2f(0.5,0.5);
#define CUSTOM_VERTEX_MAIN_BEGIN
vertexOutputs.vUV=vertexInputs.position*madd+madd;vertexOutputs.position= vec4f(vertexInputs.position,0.0,1.0);
#define CUSTOM_VERTEX_MAIN_END
}`;t.ShadersStoreWGSL[e]||(t.ShadersStoreWGSL[e]=r);const s={name:e,shader:r};export{s as glowMapMergeVertexShaderWGSL};
