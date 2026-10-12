// Kinecto Virtual Lab: PVDF elbow zone. Put on each elbow zone mesh; point upperArm/lowerArm at the humanoid bones.
// Every completed bend (rise then fall of the elbow angle) feeds HarvestModel: bend stroke + release stroke.
using UnityEngine;

public class JointBendSensor : MonoBehaviour
{
    public HarvestModel model;
    public Transform upperArm, lowerArm;
    public Renderer zoneRenderer;   // glows when energy is made
    public Color idle = new Color(0.94f, 0.63f, 0f, 0.3f), active = new Color(0.94f, 0.63f, 0f, 1f);

    float last, low, high; bool rising; bool started;

    void LateUpdate()
    {
        float angle = Vector3.Angle(upperArm.up, lowerArm.up);   // elbow bend, degrees
        if (!started) { last = low = high = angle; started = true; return; }

        if (angle > last + 0.05f) { if (!rising) { low = last; rising = true; } high = angle; }
        else if (angle < last - 0.05f && rising)
        {
            rising = false;
            float stroke = high - low;
            if (stroke > 3f) { model.AddPvdfBend(stroke); model.AddPvdfBend(stroke); Flash(); }
        }
        last = angle;
        if (zoneRenderer) zoneRenderer.material.color = Color.Lerp(zoneRenderer.material.color, idle, Time.deltaTime * 3f);
    }

    void Flash() { if (zoneRenderer) zoneRenderer.material.color = active; }
}
