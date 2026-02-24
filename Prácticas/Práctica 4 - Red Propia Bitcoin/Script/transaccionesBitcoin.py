import asyncio
import websockets
import json
import csv

# Función para guardar los nodos en un archivo CSV
def save_nodes_to_csv(nodes):
    with open('nodes.csv', 'w', newline='') as csvfile:
        fieldnames = ['addr', 'value']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        writer.writeheader()
        for node in nodes:
            writer.writerow(node)

# Función para guardar los enlaces (transacciones entre direcciones) en un archivo CSV
def save_edges_to_csv(edges):
    with open('edges.csv', 'w', newline='') as csvfile:
        fieldnames = ['source', 'target', 'value']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        writer.writeheader()
        for edge in edges:
            writer.writerow(edge)

# Función para procesar los datos de las transacciones
async def main():
    # Conectar al WebSocket de Blockchain.com
    async with websockets.connect("wss://ws.blockchain.info/inv") as client:
        print("[main] Connected to wss://ws.blockchain.info/inv")

        # Enviar comando para suscribirse a las transacciones no confirmadas
        cmd = '{"op":"unconfirmed_sub"}'
        print('[main] Send:', cmd)
        await client.send(cmd)

        # Listas para almacenar los nodos y enlaces
        nodes = []
        edges = []

        # Esperar por las transacciones
        while True:
            # Recibir datos de la transacción
            message = await client.recv()
            print('[main] Recv:', message)

            # Convertir el mensaje a formato JSON
            transaction_data = json.loads(message)

            if 'x' in transaction_data:
                tx = transaction_data['x']

                # Extraer nodos de entrada
                for input_tx in tx['inputs']:
                    addr_in = input_tx['prev_out']['addr']
                    value_in = input_tx['prev_out']['value']
                    nodes.append({'addr': addr_in, 'value': value_in})

                    # Crear los enlaces (edges)
                    for output_tx in tx['out']:
                        addr_out = output_tx['addr']
                        value_out = output_tx['value']
                        edges.append({'source': addr_in, 'target': addr_out, 'value': value_in})

                # Extraer nodos de salida
                for output_tx in tx['out']:
                    addr_out = output_tx['addr']
                    value_out = output_tx['value']
                    nodes.append({'addr': addr_out, 'value': value_out})

                # Guardar los nodos y enlaces en los archivos CSV
                save_nodes_to_csv(nodes)
                save_edges_to_csv(edges)

if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())
