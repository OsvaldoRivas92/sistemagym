import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VencimientosScreen extends StatefulWidget {
  const VencimientosScreen({super.key});

  @override
  State<VencimientosScreen> createState() => _VencimientosScreenState();
}

class _VencimientosScreenState extends State<VencimientosScreen> {
  String _filtro = 'todos';
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Control de Pagos'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Todos'),
              Tab(text: 'Vencidos'),
              Tab(text: 'Próximos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildListaClientes('todos'),
            _buildListaClientes('vencidos'),
            _buildListaClientes('proximos'),
          ],
        ),
      ),
    );
  }

  Widget _buildListaClientes(String filtro) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clientes')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 50, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final clientes = snapshot.data!.docs;
        final hoy = DateTime.now();

        // Filtrar según el tab
        final clientesFiltrados = clientes.where((cliente) {
          final fechaPago = (cliente['fechaPago'] as Timestamp).toDate();
          final diasRestantes = fechaPago.difference(hoy).inDays;

          if (filtro == 'vencidos') return diasRestantes < 0;
          if (filtro == 'proximos')
            return diasRestantes >= 0 && diasRestantes <= 5;
          return true;
        }).toList();

        // Ordenar por fecha
        clientesFiltrados.sort((a, b) {
          final fechaA = (a['fechaPago'] as Timestamp).toDate();
          final fechaB = (b['fechaPago'] as Timestamp).toDate();
          return fechaA.compareTo(fechaB);
        });

        if (clientesFiltrados.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.celebration,
                  size: 80,
                  color: filtro == 'vencidos' ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  filtro == 'vencidos'
                      ? 'No hay clientes vencidos'
                      : filtro == 'proximos'
                      ? 'No hay clientes próximos a vencer'
                      : 'No hay clientes registrados',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(8),
          itemCount: clientesFiltrados.length,
          itemBuilder: (context, index) {
            final cliente = clientesFiltrados[index];
            return _buildVencimientoCard(cliente);
          },
        );
      },
    );
  }

  Widget _buildVencimientoCard(DocumentSnapshot cliente) {
    final fechaPago = (cliente['fechaPago'] as Timestamp).toDate();
    final diasRestantes = fechaPago.difference(DateTime.now()).inDays;

    Color estadoColor;
    String estadoTexto;

    if (diasRestantes < 0) {
      estadoColor = Colors.red;
      estadoTexto = 'VENCIDO';
    } else if (diasRestantes == 0) {
      estadoColor = Colors.orange;
      estadoTexto = 'VENCE HOY';
    } else if (diasRestantes <= 3) {
      estadoColor = Colors.orange;
      estadoTexto = 'Vence en $diasRestantes días';
    } else {
      estadoColor = Colors.green;
      estadoTexto = 'Al día';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: diasRestantes < 0
            ? BorderSide(color: estadoColor, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: estadoColor,
          child: Icon(
            diasRestantes < 0 ? Icons.warning : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          cliente['nombre'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Tel: ${cliente['telefono']} | Cuota: \$${cliente['montoCuota']}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              estadoTexto,
              style: TextStyle(
                color: estadoColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy').format(fechaPago),
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        onTap: () => _registrarPagoRapido(cliente),
      ),
    );
  }

  void _registrarPagoRapido(DocumentSnapshot cliente) async {
    String? metodoPagoSeleccionado;

    // Mostrar diálogo de confirmación con método de pago
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Registrar Pago'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cliente: ${cliente['nombre']}'),
                const SizedBox(height: 8),
                Text(
                  'Monto: \$${cliente['montoCuota']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: metodoPagoSeleccionado,
                  hint: const Text('Seleccione método de pago'),
                  items: ['Efectivo', 'Tarjeta', 'Transferencia', 'QR']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      metodoPagoSeleccionado = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null ? 'Seleccione un método' : null,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (metodoPagoSeleccionado == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Seleccione un método de pago'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Confirmar Pago'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmar == true && metodoPagoSeleccionado != null && mounted) {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingContext) =>
            const Center(child: CircularProgressIndicator()),
      );

      try {
        // Registrar pago con método de pago
        await FirebaseFirestore.instance.collection('pagos').add({
          'clienteId': cliente.id,
          'clienteNombre': cliente['nombre'],
          'monto': cliente['montoCuota'],
          'fechaPago': DateTime.now(),
          'metodoPago': metodoPagoSeleccionado,
          'periodo': _formatearFecha(DateTime.now()),
        });

        // Actualizar fecha de pago
        final fechaActualPago = (cliente['fechaPago'] as Timestamp).toDate();
        final nuevaFecha = fechaActualPago.add(const Duration(days: 30));
        await cliente.reference.update({'fechaPago': nuevaFecha});

        // Cerrar loading si aún está montado
        if (mounted) {
          Navigator.pop(context); // Cerrar loading

          // Mostrar éxito
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Pago de \$${cliente['montoCuota']} registrado con ${metodoPagoSeleccionado}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Cerrar loading
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    final meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }
}
