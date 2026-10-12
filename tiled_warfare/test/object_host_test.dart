import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/objects/boss_monsters/object_dough_dumpster.dart';
import 'package:tiled_warfare/objects/monsters/object_dough_zombie.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/frt_service.dart';

/// Tests der FRT-Monster-Skalierung (Kapitel 14, Q3): Dough Zombies **und**
/// Spawner (Dough Dumpster) skalieren deterministisch aus der
/// Stadtteil-Korruption zum Spawn-Zeitpunkt.
void main() {
  group('Monsterstärke-Faktor (FrtService)', () {
    test('0 % Korruption ⇒ neutraler Faktor 1.0', () {
      expect(FrtService.monsterStrengthFactor(0), 1.0);
    });

    test('100 % Korruption ⇒ 1 + Scale/100', () {
      expect(
        FrtService.monsterStrengthFactor(100),
        1 + EconomyBalance.frtMonsterStrengthScalePercent / 100,
      );
    });

    test('50 % Korruption liegt zwischen den Enden (deterministisch)', () {
      final half = FrtService.monsterStrengthFactor(50);
      expect(half, greaterThan(1.0));
      expect(half, lessThan(FrtService.monsterStrengthFactor(100)));
    });
  });

  group('ObjectDoughZombie – Skalierung', () {
    test('Faktor 1.0 reproduziert exakt die Basis-Werte', () {
      final zombie = ObjectDoughZombie();
      expect(zombie.attackValue, EconomyBalance.doughZombieStats.attack);
      expect(zombie.defenseValue, EconomyBalance.doughZombieStats.defense);
      expect(zombie.damageValue, EconomyBalance.doughZombieStats.damage);
      expect(zombie.woundValue, EconomyBalance.doughZombieStats.wound);
      expect(zombie.movementValue, EconomyBalance.doughZombieStats.movement);
    });

    test('Faktor skaliert jeden Statwert deterministisch (.round())', () {
      const factor = 1.5;
      final zombie = ObjectDoughZombie(strengthFactor: factor);
      expect(
        zombie.attackValue,
        FrtService.scaleStat(EconomyBalance.doughZombieStats.attack, factor),
      );
      expect(
        zombie.defenseValue,
        FrtService.scaleStat(EconomyBalance.doughZombieStats.defense, factor),
      );
      expect(
        zombie.damageValue,
        FrtService.scaleStat(EconomyBalance.doughZombieStats.damage, factor),
      );
      expect(
        zombie.moneyValue,
        FrtService.scaleStat(EconomyBalance.doughZombieStats.money, factor),
      );
    });
  });

  group('ObjectDoughDumpster – Skalierung & Weitergabe', () {
    test('Faktor skaliert den Spawner selbst', () {
      const factor = 2.0;
      final dumpster = ObjectDoughDumpster(strengthFactor: factor);
      expect(dumpster.strengthFactor, factor);
      expect(
        dumpster.woundValue,
        FrtService.scaleStat(EconomyBalance.doughDumpsterStats.wound, factor),
      );
      expect(
        dumpster.attackValue,
        FrtService.scaleStat(EconomyBalance.doughDumpsterStats.attack, factor),
      );
    });

    test('gespawnte Zombies erben den Faktor des Dumpsters', () {
      const factor = 1.5;
      final dumpster = ObjectDoughDumpster(strengthFactor: factor);
      final zombies = dumpster.spawnZombies();
      expect(zombies, isNotEmpty);
      for (final zombie in zombies) {
        expect(
          zombie.attackValue,
          FrtService.scaleStat(EconomyBalance.doughZombieStats.attack, factor),
        );
      }
    });
  });

  group('ObjectHost – Verdrahtung', () {
    test('spawnDoughDumpster nutzt monsterStrengthFactor', () {
      final host = ObjectHost();
      host.doughDumpsterList.clear();

      host.monsterStrengthFactor = 1.0;
      final plain = host.spawnDoughDumpster();
      expect(plain.strengthFactor, 1.0);
      expect(plain.attackValue, EconomyBalance.doughDumpsterStats.attack);

      host.monsterStrengthFactor = 2.0;
      final strong = host.spawnDoughDumpster();
      expect(strong.strengthFactor, 2.0);
      expect(
        strong.attackValue,
        FrtService.scaleStat(EconomyBalance.doughDumpsterStats.attack, 2.0),
      );

      // Aufräumen (Singleton-Zustand).
      host.doughDumpsterList.clear();
      host.monsterStrengthFactor = 1.0;
    });

    test('spawnAllZombies skaliert aus dem Dumpster-Faktor', () {
      final host = ObjectHost();
      host.doughDumpsterList.clear();
      host.monsterStrengthFactor = 1.5;
      host.spawnDoughDumpster();

      final zombies = host.spawnAllZombies();
      expect(zombies, isNotEmpty);
      for (final zombie in zombies) {
        expect(
          zombie.attackValue,
          FrtService.scaleStat(EconomyBalance.doughZombieStats.attack, 1.5),
        );
      }

      host.doughDumpsterList.clear();
      host.monsterStrengthFactor = 1.0;
    });
  });
}
