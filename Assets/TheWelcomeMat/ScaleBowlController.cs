using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ScaleBowlController : MonoBehaviour
{
    public Transform spawnLocation;
    public Transform spawnArea;
    public Transform bowlLocation;
    public BowlTriggerController trigger;
    public int TouchingCount
    {
        get { return trigger.TouchingCount; }
    }

    public void SpawnMass()
    {
        GameObject go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        go.transform.position = new Vector3(bowlLocation.position.x + getLocationInArea().x, getLocationInArea().y, bowlLocation.position.z + getLocationInArea().z);
        go.transform.localScale = Vector3.one * 0.5f;
        Rigidbody rb = go.AddComponent<Rigidbody>();
        rb.mass = 2f;
    }
    
    Vector3 getLocationInArea()
    {
        float potentialX = Mathf.Abs(spawnArea.localPosition.x - spawnLocation.localPosition.x);
        float potentialY = Mathf.Abs(spawnArea.localPosition.y - spawnLocation.localPosition.y);
        float potentialZ = Mathf.Abs(spawnArea.localPosition.z - spawnLocation.localPosition.z);

        return new Vector3(
            Random.Range(spawnLocation.localPosition.x - potentialX, spawnLocation.localPosition.x + potentialX),
            Random.Range(spawnLocation.localPosition.y - potentialY, spawnLocation.localPosition.y + potentialY),
            Random.Range(spawnLocation.localPosition.z - potentialZ, spawnLocation.localPosition.z + potentialZ)
            );
    }
}
