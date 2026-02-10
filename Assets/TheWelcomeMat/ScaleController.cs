using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ScaleController : MonoBehaviour
{
    public ScaleBowlController LeftBowl;
    public ScaleBowlController RightBowl;

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.L))
        {
            LeftBowl.SpawnMass();
        }

        if (Input.GetKeyDown(KeyCode.R))
        {
            RightBowl.SpawnMass();
        }

        if (LeftBowl.TouchingCount == RightBowl.TouchingCount)
        {
            Debug.Log("Even");
        }
    }
}
