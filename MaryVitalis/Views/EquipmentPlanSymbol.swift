import SwiftUI

/// La sagoma di un attrezzo sulla pianta.
///
/// Disegnava una pianta vista dall'alto, con una forma diversa per ogni
/// famiglia di macchine. A quaranta punti però un leg press dall'alto e una
/// panca dall'alto sono lo stesso rettangolo: nessuno le distingueva. Ora
/// rimanda alle icone di profilo, che è come si riconosce un attrezzo quando lo
/// si cerca con gli occhi in una sala.
struct EquipmentPlanSymbol: View {
    let machine: GymMachine
    var tint: Color = Theme.textDim

    var body: some View {
        EquipmentIconView(icon: machine.icon, tint: tint, weight: 0.06)
    }
}
