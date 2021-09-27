using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PaintGrassCtrl : MonoBehaviour
{
    Camera mainCamera;

    MeshRenderer groundRender;

    [SerializeField]
    Texture2D brushTexture;
    Color[] brushColors;
    [SerializeField]
    Texture2D baseColorTexture;
    Texture2D canvasTexture;
    Color[] canvasColors;

    float colorStrength = 1f;
    float bendStrength = 0.5f;
    float restoreSpeed = 3f;
    void Start()
    {
        mainCamera = Camera.main;

        groundRender = gameObject.GetComponent<MeshRenderer>();

        copyTexture();
    }

    void Update()
    {
        //down---------------------------
        if (Input.GetMouseButton(0))
        {
            paintGround();
        }

        restoreColor();

        
    }

    void paintGround()
    {
        RaycastHit hit;
        Ray ray = mainCamera.ScreenPointToRay(Input.mousePosition);
        
        if (Physics.Raycast(ray, out hit))
        {
            //Material mat = groundRender.material;
            //Vector4 v4 = new Vector4(hit.point.x, 0, hit.point.z, 0.6f);
            //mat.SetVector("_ObjPos", v4);

            int hitX = Mathf.RoundToInt(canvasTexture.width * hit.textureCoord.x);
            int hitY = Mathf.RoundToInt(canvasTexture.height * hit.textureCoord.y);
            int brushStartX = brushTexture.width / 2;
            int brushStartY = brushTexture.height / 2;
            //Debug.Log("hitX="+ hitX+ " hitY="+ hitY+ " brushStartX="+ brushStartX+ " brushStartY="+ brushStartY);
            //canvasColors = canvasTexture.GetPixels();
            for (int i = 0; i < brushColors.Length; i++)
            {
                int brushY = i / brushTexture.width;
                int brushX = i - brushY * brushTexture.width;

                int paintX = hitX - brushStartX + brushX;
                int paintY = hitY - brushStartY + brushY;

                if (paintX <0 || paintX>= canvasTexture.width || paintY<0 || paintY>= canvasTexture.height) {
                    continue;
                }

                //Debug.Log("brushColors[i].a="+ brushColors[i].a);

                int canvasColorIndex = paintY * canvasTexture.width + paintX;

                float paintColor =  brushColors[i].r * brushColors[i].a * colorStrength + canvasColors[canvasColorIndex].r ;
                if (paintColor > bendStrength) {
                    paintColor = bendStrength;
                }
                canvasColors[canvasColorIndex].r = paintColor;
                if (paintColor < 1f)
                {
                    Vector2 paintPoint = new Vector2(paintX, paintY);
                    Vector2 hitPoint = new Vector2(hitX, hitY);
                    Vector2 tipDir = (paintPoint - hitPoint).normalized;
                    canvasColors[canvasColorIndex].g = tipDir.x * brushColors[i].a * colorStrength + canvasColors[canvasColorIndex].g;
                    canvasColors[canvasColorIndex].b = tipDir.y * brushColors[i].a * colorStrength + canvasColors[canvasColorIndex].b;
                }
                else {
                    //canvasColors[canvasColorIndex].g = paintColor;
                    //canvasColors[canvasColorIndex].b = paintColor;
                }
                
            }
            canvasTexture.SetPixels(canvasColors);
            canvasTexture.Apply();

            groundRender.material.SetTexture("_OverwhelmTex", canvasTexture);
        }

    }

    void copyTexture() {
        canvasTexture = new Texture2D(baseColorTexture.width, baseColorTexture.height, TextureFormat.RGBAHalf, false);
        //paintTexture.wrapMode = TextureWrapMode.Clamp;
        canvasColors = baseColorTexture.GetPixels();

        canvasTexture.SetPixels(canvasColors);
        canvasTexture.Apply();

        groundRender.material.SetTexture("_OverwhelmTex", canvasTexture);


        brushColors = brushTexture.GetPixels();
    }

    void restoreColor() {
        //canvasColors = canvasTexture.GetPixels();
        for (int i = 0; i < canvasColors.Length; i++)
        {
            if (canvasColors[i].r >0)
            {
                float restoreColor = Mathf.Lerp(canvasColors[i].r, 0, Time.deltaTime * restoreSpeed);
                canvasColors[i].r = restoreColor;
            }
            if (canvasColors[i].g >0)
            {
                float restoreColor = Mathf.Lerp(canvasColors[i].g, 0, Time.deltaTime * restoreSpeed);
                canvasColors[i].g = restoreColor;
            }
            if (canvasColors[i].b >0)
            {
                float restoreColor = Mathf.Lerp(canvasColors[i].b, 0, Time.deltaTime * restoreSpeed);
                canvasColors[i].b = restoreColor;
            }
        }
        canvasTexture.SetPixels(canvasColors);
        canvasTexture.Apply();

        groundRender.material.SetTexture("_OverwhelmTex", canvasTexture);
    }
}
