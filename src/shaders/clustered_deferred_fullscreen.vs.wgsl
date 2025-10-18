struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
}

@vertex
fn main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput
{
    /*
    screen spanning biiiiiig triangle
        (-1,3) 
        *
        |\
        | \
        |  \ 
        |   \
        |___ \
        |*  |*\
        |   |  \
    (-1,-1)*----*(3,-1)
    */
    var positions = array<vec2<f32>, 3>(
        vec2<f32>(-1.0, -1.0),  
        vec2<f32>(-1.0, 3.0),   
        vec2<f32>(3.0, -1.0)     
    );

    var out: VertexOutput;
    out.fragPos = vec4<f32>(positions[vertexIndex], 0.0, 1.0);

    return out;
}