uniform highp vec2 u_out_pixel_size; // 2.0 / w, -2.0 / h
uniform highp vec2 u_out_offset;

uniform highp mat3 u_cmatrix;

attribute highp vec2 a_VertexPos;

#ifdef DRAW_FANCY
attribute lowp vec4 a_VertexColor;
attribute frag_highp vec2 a_VertexTexCoord;

out lowp vec4 v_drawColor;
out frag_highp vec2 v_texCoord;
#endif

void main()
{
  // Transform pixel coordinates
  highp vec3 eye_pos = u_cmatrix * vec3(a_VertexPos, 1.0);
  highp vec2 local_xy = eye_pos.xy - eye_pos.z*u_out_offset;
  highp vec2 clip_xy = local_xy * u_out_pixel_size;
  gl_Position = vec4(clip_xy, 0.0, eye_pos.z);

#ifdef DRAW_FANCY
  // Copy properties
  v_drawColor = a_VertexColor;
  v_texCoord = a_VertexTexCoord;
#endif
}
