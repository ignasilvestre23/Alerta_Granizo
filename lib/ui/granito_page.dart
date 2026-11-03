import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'widgets.dart';

class GranitoPage extends StatelessWidget {
  const GranitoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const tips = [
      ('🚗', 'Poné el auto bajo techo o en una cochera antes de que llegue la tormenta.'),
      ('🏠', 'Alejate de ventanas y claraboyas. Cerrá persianas si tenés.'),
      ('🌳', 'No te refugies bajo árboles aislados: atraen rayos.'),
      ('📱', 'Si estás manejando, buscá un puente o estación de servicio cubierta. No frenes en la banquina.'),
      ('⚡', 'Si hay rayos, desenchufá equipos sensibles y evitá usar agua.'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Container(
              width: 70,
              height: 70,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFF7CC4F5)),
              child: const Text('🧊', style: TextStyle(fontSize: 38)),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text('Granito',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Qué hacer si hay granizo',
            style: TextStyle(fontSize: 19, color: context.muted)),
        const SizedBox(height: 16),
        for (final t in tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Row(
                children: [
                  Text(t.$1, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Text(t.$2,
                          style: const TextStyle(fontSize: 17, height: 1.35))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
