using UnityEngine;

namespace NightFactoryDefence
{
    // 加工炉。一定間隔で鉄を消費して弾薬を生産する(鉄1→弾薬2)。
    // 鉄が足りないときは貯まるまで待機する。
    // レリック「効率炉」で弾薬生産にボーナスが乗る(GameManager側で加算)。
    [RequireComponent(typeof(NfdBuilding))]
    public sealed class NfdSmelter : MonoBehaviour
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
            if (timer < building.Data.interval) return;

            var ironIn = Mathf.RoundToInt(building.Data.ironIn);
            if (manager.TrySpendIron(ironIn))
            {
                timer -= building.Data.interval;
                var ammoOut = Mathf.RoundToInt(building.Data.ammoOut) + manager.SmelterBonus;
                manager.AddAmmo(ammoOut);
            }
            else
            {
                // 鉄が無いので次に鉄が来たら即生産できるよう、タイマーを間隔で止める
                timer = building.Data.interval;
            }
        }
    }
}
