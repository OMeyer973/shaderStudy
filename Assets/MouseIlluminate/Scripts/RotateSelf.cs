using UnityEngine;

//Attach this script to a GameObject to rotate around the target position.
public class RotateSelf : MonoBehaviour
{
    public float rotateSpeed = 10;
    private Vector3 target = new Vector3(0.0f, 1.0f, 0.0f);

    void Update()
    {
        // Spin the object around the world origin at 20 degrees/second.
        transform.RotateAround(target, Vector3.up, rotateSpeed * Time.deltaTime);
    }
}