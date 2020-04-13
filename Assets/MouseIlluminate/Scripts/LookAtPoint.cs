using UnityEngine;

//Attach this script to a GameObject to rotate around the target position.
public class LookAtPoint : MonoBehaviour
{
    public Vector3 pointToLookAt;
    void Update()
    {
        // Spin the object around the world origin at 20 degrees/second.
        transform.LookAt(pointToLookAt);
    }
}