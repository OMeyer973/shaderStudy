using UnityEngine;

//Attach this script to a GameObject to rotate around the target position.
public class OscillateSelf : MonoBehaviour
{

    public float freq = 10;
    public float amp = 10;
    private Vector3 origPos;

    private void Start()
    {
        origPos = transform.position;
    }
    void Update()
    {
        // Spin the object around the world origin at 20 degrees/second.
        Vector3 newPos = new Vector3(transform.position.x, origPos.y + Mathf.Sin(Time.time * freq) * amp, transform.position.z);
        transform.position = newPos;
    }
}