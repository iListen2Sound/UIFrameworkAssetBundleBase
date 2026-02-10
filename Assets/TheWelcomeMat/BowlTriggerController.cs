using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BowlTriggerController : MonoBehaviour
{
    // Public variable to view all touching rigidbodies in the inspector
    HashSet<Rigidbody> TouchingRigidbodies = new HashSet<Rigidbody>();
    public int TouchingCount
    {
        get { return TouchingRigidbodies.Count; }
    }

    private void OnTriggerEnter(Collider other)
    {
        var rb = other.attachedRigidbody;
        if (rb != null)
        {
            TouchingRigidbodies.Add(rb);
        }
    }

    private void OnTriggerExit(Collider other)
    {
        var rb = other.attachedRigidbody;
        if (rb != null)
        {
            TouchingRigidbodies.Remove(rb);
        }
    }
}
