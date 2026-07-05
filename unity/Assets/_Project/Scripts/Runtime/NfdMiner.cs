using UnityEngine;

namespace NightFactoryDefence
{
    // 採掘機。鉱床の上に設置され、一定間隔で鉄を自動生産する。
    // ステータスは同じGameObjectの NfdBuilding.Data から読む。
    [RequireComponent(typeof(NfdBuilding))]
    public sealed class NfdMiner : MonoBehaviour
    {
        NfdBuilding building;
        float timer;

        void Awake()
        {
            building = GetComponent<NfdBuilding>();
        }

        void Update()
        {
            var manager = NfdGameManager.Instance;
            if (manager == null || manager.IsRunEnded || building.Data == null) return;

            timer += Time.deltaTime;
            if (timer >= building.Data.interval)
            {
                timer -= building.Data.interval;
                manager.AddIron(Mathf.RoundToInt(building.Data.output));
            }
        }
    }
}
