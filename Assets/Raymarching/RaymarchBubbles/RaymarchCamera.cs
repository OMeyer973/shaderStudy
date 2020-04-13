using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode] // si that we can see the raymarching even when scene not playing
public class RaymarchCamera : SceneViewFilter
{

    #region RAYMARCHING_THINGS
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
    public float _maxDistance = 2000;
    [Range(4,2048)] 
    public int _maxIterations = 512;
    [Range(0.0001f, 1)]
    public float _accuracy = 0.001f;
    [Header("scene geometry")]
    public Vector4 _sphere = new Vector4(0,1.1f,0,.4f);
    public float _smoothFactor = .38f;
    public float _angularOffset = 20f;
    public float _groundHeight = 0;
    [Header("material")]
    public Color _groundColor = Color.white;
    public Gradient _sphereGradient;
    static private int _nSphereColors = 8;
    private Color[] _sphereColors = new Color[_nSphereColors];
    public float _colorIntensity = 1;
    [Header("light & shadows")]
    public Light _directionalLight;
    public Vector2 _shadowDistance = new Vector2(.1f, 100);
    public float _shadowIntensity = 1;
    public float _shadowSoftness = .4f;
    [Header("ambient occlusion")]
    public float _aOStepSize = .01f;
    public int _aOIterations = 8;
    public float _aOIntensity = .1f;
    [Header("reflexions")]
    public int _reflexionCount = 1;
    public float _reflexionIntensity = .5f;
    public float _envReflIntensity = .5f;
    public Cubemap _reflexionCube;



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
        _raymarchMat.SetFloat("_smoothFactor", _smoothFactor);
        _raymarchMat.SetFloat("_angularOffset", _angularOffset * 0.0174533f); // deg2rad conversion
        _raymarchMat.SetFloat("_groundHeight", _groundHeight);
        _raymarchMat.SetFloat("_smoothFactor", _smoothFactor);
        // material
        _raymarchMat.SetColor("_groundColor", _groundColor);
        for (int i=0; i <  _nSphereColors; i++)
        {
            _sphereColors[i] = _sphereGradient.Evaluate((float)i / _nSphereColors);
        }
        _raymarchMat.SetColorArray("_sphereColors", _sphereColors);
        _raymarchMat.SetFloat("_colorIntensity", _colorIntensity);
        // light & shadows
        _raymarchMat.SetVector("_lightDirection", _directionalLight ? _directionalLight.transform.forward : Vector3.down);
        _raymarchMat.SetColor("_lightColor", _directionalLight ? _directionalLight.color : Color.white);
        _raymarchMat.SetFloat("_lightIntensity", _directionalLight ? _directionalLight.intensity : 1);
        _raymarchMat.SetVector("_shadowDistance", _shadowDistance);
        _raymarchMat.SetFloat("_shadowIntensity", _shadowIntensity);
        _raymarchMat.SetFloat("_shadowSharpness", Mathf.Pow(8,1/_shadowSoftness));
        // ambient occlusion
        _raymarchMat.SetFloat("_aOStepSize", _aOStepSize);
        _raymarchMat.SetInt("_aOIterations", _aOIterations);
        _raymarchMat.SetFloat("_aOIntensity", _aOIntensity);
        // reflexions
        _raymarchMat.SetInt("_reflexionCount", _reflexionCount);
        _raymarchMat.SetFloat("_reflexionIntensity", _reflexionIntensity);
        _raymarchMat.SetFloat("_envReflIntensity", _envReflIntensity);
        _raymarchMat.SetTexture("_reflexionCube", _reflexionCube);

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
    #endregion RAYMARCHING_THINGS


    #region ANIMATING_THE_SCENE

    private Vector4 _sphereOrig;
    private float _smoothFactorOrig;
    private float _angularOffsetOrig;
    private float _groundHeightOrig;

    public void Start()
    {
        _sphereOrig = _sphere;
        _smoothFactorOrig = _smoothFactor;
        _angularOffsetOrig = _angularOffset;
        _groundHeightOrig = _groundHeight;
    }

    public void Update()
    {
        _angularOffset -= 10 * Time.deltaTime;
    }
    #endregion ANIMATING_THE_SCENE
}
