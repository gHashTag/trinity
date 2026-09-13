import{ar as t}from"./QueenComb-C90itEMJ.js";import"./index-C6qSoOuU.js";import"./react-BikoVsHo.js";import"./motion-DmZWFm6O.js";import"./router-CAi4bOxy.js";import"./queenRepositoryWorld-DQIYnztg.js";const e="glowMapMergeVertexShader",r=`attribute position: vec2f;varying vUV: vec2f;
#define CUSTOM_VERTEX_DEFINITIONS
@vertex
fn main(input : VertexInputs)->FragmentInputs {const madd: vec2f= vec2f(0.5,0.5);
#define CUSTOM_VERTEX_MAIN_BEGIN
vertexOutputs.vUV=vertexInputs.position*madd+madd;vertexOutputs.position= vec4f(vertexInputs.position,0.0,1.0);
#define CUSTOM_VERTEX_MAIN_END
}`;t.ShadersStoreWGSL[e]||(t.ShadersStoreWGSL[e]=r);const d={name:e,shader:r};export{d as glowMapMergeVertexShaderWGSL};
