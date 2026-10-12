// Kinecto Virtual Lab: campus sun / shade areas. Put on a trigger box (e.g. a solar canopy's shade, an open plaza).
// While the person stands inside, the outside temperature the jacket feels shifts by offsetC
// (shade about -3 °C, open sun about +3 °C on a Windhoek afternoon). Comfort model only, SIMULATED.
using UnityEngine;

[RequireComponent(typeof(Collider))]
public class SunShadeZone : MonoBehaviour
{
    public KinectoLabController lab;
    public float offsetC = -3f;
    public string zoneName = "Shade";

    void Reset() { GetComponent<Collider>().isTrigger = true; }

    void OnTriggerEnter(Collider other) { if (IsPerson(other)) lab.shadeOffsetC = offsetC; }
    void OnTriggerExit(Collider other)  { if (IsPerson(other)) lab.shadeOffsetC = 0f; }

    bool IsPerson(Collider c) => c.GetComponent<CharacterController>() != null;
}
