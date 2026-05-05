import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'clientes_screen.dart';
import 'tienda_screen.dart';
import 'agenda_screen.dart';
import 'vencimientos_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalClientes = 0;
  int _clientesVencidos = 0;
  double _ingresosMes = 0;
  int _reservasHoy = 0;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  void _cargarEstadisticas() {
    // Total de clientes activos
    FirebaseFirestore.instance
        .collection('clientes')
        .where('activo', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _totalClientes = snapshot.docs.length;
          });
        });

    // Clientes vencidos
    FirebaseFirestore.instance
        .collection('clientes')
        .where('activo', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          final hoy = DateTime.now();
          int vencidos = 0;
          for (var doc in snapshot.docs) {
            final fechaPago = (doc['fechaPago'] as Timestamp).toDate();
            if (fechaPago.difference(hoy).inDays < 0) {
              vencidos++;
            }
          }
          setState(() {
            _clientesVencidos = vencidos;
          });
        });

    // Ingresos del mes (pagos registrados)
    final inicioMes = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final finMes = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

    FirebaseFirestore.instance
        .collection('pagos')
        .where('fechaPago', isGreaterThanOrEqualTo: inicioMes)
        .where('fechaPago', isLessThanOrEqualTo: finMes)
        .snapshots()
        .listen((snapshot) {
          double total = 0;
          for (var doc in snapshot.docs) {
            total += (doc['monto'] as num).toDouble();
          }
          setState(() {
            _ingresosMes = total;
          });
        });

    // Reservas de hoy
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
    final finDia = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);

    FirebaseFirestore.instance
        .collection('reservas_cancha')
        .where('fecha', isGreaterThanOrEqualTo: inicioDia)
        .where('fecha', isLessThanOrEqualTo: finDia)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _reservasHoy = snapshot.docs.length;
          });
        });
  }

  String _formatearIngresos(double monto) {
    if (monto >= 1000000) {
      return 'Gs ${(monto / 1000000).toStringAsFixed(1)}M';
    } else if (monto >= 1000) {
      return 'Gs ${(monto / 1000).toStringAsFixed(0)}k';
    }
    return 'Gs ${monto.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👋 Header
              const Text(
                'Hola 👋',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'Panel de Control',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // 📊 RESUMEN
              Row(
                children: [
                  _cardMini('Clientes', '$_totalClientes', Colors.blue),
                  const SizedBox(width: 12),
                  _cardMini(
                    'Ingresos',
                    _formatearIngresos(_ingresosMes),
                    Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _cardMiniVencidos(
                    'Vencidos',
                    '$_clientesVencidos',
                    Colors.red,
                    context,
                  ),
                  const SizedBox(width: 12),
                  _cardMini('Reservas', '$_reservasHoy', Colors.orange),
                ],
              ),

              const SizedBox(height: 30),

              // ⚡ Acciones
              const Text(
                'Acciones',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _tarjeta(
                      context,
                      'Clientes',
                      Icons.people,
                      Colors.blue,
                      const ClientesScreen(),
                    ),
                    _tarjeta(
                      context,
                      'Control Pagos',
                      Icons.warning,
                      Colors.red,
                      const VencimientosScreen(),
                    ),
                    _tarjeta(
                      context,
                      'Tienda',
                      Icons.store,
                      Colors.orange,
                      TiendaScreen(),
                    ),
                    _tarjeta(
                      context,
                      'Cancha',
                      Icons.sports_soccer,
                      Colors.green,
                      AgendaScreen(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Cards pequeñas (stats)
  Widget _cardMini(String titulo, String valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              valor,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card para vencidos (que se pueda tocar)
  Widget _cardMiniVencidos(
    String titulo,
    String valor,
    Color color,
    BuildContext context,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VencimientosScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: _clientesVencidos > 0
                ? Border.all(color: Colors.red, width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (_clientesVencidos > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('⚠️', style: TextStyle(fontSize: 10)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                valor,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Cards grandes (acciones)
  Widget _tarjeta(
    BuildContext context,
    String titulo,
    IconData icono,
    Color color,
    Widget pantalla,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 30),
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
