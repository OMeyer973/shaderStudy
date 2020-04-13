using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode] // si that we can see the raymarching even when scene not playing
public class RaymarchDonutCamera : SceneViewFilter
{
    [SerializeField]
    private Shader _shader; // private material that we will use

    public Material _raymarchMaterial // public material to be accessed by the exterior
    {
        get
        {
            if (!_raymarchMat && _shader)
            {
                _raymarchMat = new Material(_shader);
                _raymarchMat.hideFlags = HideFlags.HideAndDontSave; // prevent garbage collection
            }
            return _raymarchMat;
        }
    }
    private Material _raymarchMat;

    public Camera _camera
    {
        get
        {
            if (!_cam)
                _cam = GetComponent<Camera>();
            return _cam;
        }
    }
    private Camera _cam;

    [Header("render")]
    public float _maxDistance = 50;
    public int _maxIterations = 128;
    public float _accuracy = 0.001f;
    [Header("scene geometry")]
    public Vector4 _sphere = new Vector4(0, 0, 0, 1.7f);
    public Vector3 _torusPos = new Vector4(0, 0, 0);
    public Vector2 _torusSize = new Vector2(4, 1);
    [Header("animation")]
    public float _wiggleFreg = 1;
    public float _wiggleAmp = 1;

    // send the camera info to the shader
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!_raymarchMaterial)
        {
            Debug.LogError("No raymarch material assigned");
            Graphics.Blit(source, destination);
            return;
        }

        // render
        _raymarchMat.SetMatrix("_CamFrustum", CamFrustum(_camera));
        _raymarchMat.SetMatrix("_CamToWorld", _camera.cameraToWorldMatrix);
        _raymarchMat.SetFloat("_maxDistance", _maxDistance);
        _raymarchMat.SetInt("_maxIterations", _maxIterations);
        _raymarchMat.SetFloat("_accuracy", _accuracy);
        // scene geometry
        _raymarchMat.SetVector("_sphere", _sphere);
        _raymarchMat.SetVector("_torusPos", _torusPos);
        _raymarchMat.SetVector("_torusSize", _torusSize);

        RenderTexture.active = destination;
        _raymarchMat.SetTexture("_MainTex", source);

        GL.PushMatrix();
        GL.LoadOrtho();
        _raymarchMaterial.SetPass(0);
        
        // rendering the quad on wich the raymarch scene will be drawn
        GL.Begin(GL.QUADS);
        // BL vertex
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);
        // BR vertex
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        // TR vertex
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        // TL vertex
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();
    }

    // calculate the 4 corners of the camera frustum
    private Matrix4x4 CamFrustum (Camera cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan((cam.fieldOfView * 0.5f) * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 TL = ( - Vector3.forward - goRight + goUp);
        Vector3 TR = ( - Vector3.forward + goRight + goUp);
        Vector3 BL = ( - Vector3.forward - goRight - goUp);
        Vector3 BR = ( - Vector3.forward + goRight - goUp);

        frustum.SetRow(0, TL);
        frustum.SetRow(1, TR);
        frustum.SetRow(2, BR);
        frustum.SetRow(3, BL);

        return frustum;
    }

    // animation shenanigans
    private Vector4 _sphereOrig;

    public void Start()
    {
        _sphereOrig = _sphere;
    }

    public void Update()
    {
        float spherePosY = 0 + Mathf.Sin(Time.time * _wiggleFreg) * _wiggleAmp;
        float spherePosX = 0 + Mathf.Sin(Time.time * _wiggleFreg * .5f) * _wiggleAmp*2;

        _sphere = new Vector4(spherePosX, spherePosY, _sphere.z, _sphere.w);        
    }

}
