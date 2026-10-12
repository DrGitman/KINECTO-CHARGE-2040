// Kinecto Virtual Lab: moves the directional light with the lab clock, so the campus goes from morning to evening
// in day mode (and the sun / shade areas make visual sense). Sunrise ~06:00, noon overhead, sunset ~18:30.
using UnityEngine;

public class DaySun : MonoBehaviour
{
    public KinectoLabController lab;
    public Light sun;
    public float northOffset = 30f;            // rotate to match your campus layout
    public Gradient colour;                    // optional: warm at dawn/dusk, white at noon

    void Update()
    {
        float h = lab.DayHours % 24f;
        float t = Mathf.InverseLerp(6f, 18.5f, h);              // 0 at sunrise, 1 at sunset
        float elevation = Mathf.Sin(t * Mathf.PI) * 75f;          // max 75 degrees
        transform.rotation = Quaternion.Euler(elevation, northOffset + Mathf.Lerp(-90f, 90f, t), 0f);
        if (sun)
        {
            sun.intensity = h < 6f || h > 18.5f ? 0.05f : Mathf.Lerp(0.3f, 1.2f, Mathf.Sin(t * Mathf.PI));
            if (colour != null && colour.colorKeys.Length > 1) sun.color = colour.Evaluate(t);
        }
    }
}
