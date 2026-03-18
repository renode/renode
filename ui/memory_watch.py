from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QTableWidget, QTableWidgetItem,
    QPushButton, QHeaderView, QDialog, QFormLayout, QLineEdit, QComboBox,
    QDialogButtonBox, QMessageBox
)
from PySide6.QtCore import Qt

class AddWatchDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Add Memory Watch")
        
        self.layout = QVBoxLayout(self)
        self.form_layout = QFormLayout()
        
        self.address_input = QLineEdit()
        self.name_input = QLineEdit()
        self.type_input = QComboBox()
        self.type_input.addItems(["Word", "Byte", "HalfWord"])
        
        self.form_layout.addRow("Address (Hex):", self.address_input)
        self.form_layout.addRow("Name:", self.name_input)
        self.form_layout.addRow("Type:", self.type_input)
        
        self.layout.addLayout(self.form_layout)
        
        self.buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        self.buttons.accepted.connect(self.accept)
        self.buttons.rejected.connect(self.reject)
        self.layout.addWidget(self.buttons)

    def get_data(self):
        return {
            "address": self.address_input.text(),
            "name": self.name_input.text(),
            "type": self.type_input.currentText()
        }

class MemoryWatchWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.layout = QVBoxLayout(self)
        
        # Table
        self.table = QTableWidget()
        self.table.setColumnCount(4)
        self.table.setHorizontalHeaderLabels(["Address", "Name", "Type", "Value"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.layout.addWidget(self.table)
        
        # Buttons
        btn_layout = QHBoxLayout()
        self.add_btn = QPushButton("Add Watch")
        self.add_btn.clicked.connect(self.add_watch)
        self.remove_btn = QPushButton("Remove Watch")
        self.remove_btn.clicked.connect(self.remove_watch)
        
        btn_layout.addWidget(self.add_btn)
        btn_layout.addWidget(self.remove_btn)
        self.layout.addLayout(btn_layout)
        
        self.watches = [] # List of dicts: {address, name, type, row_index}

    def add_watch(self):
        dialog = AddWatchDialog(self)
        if dialog.exec():
            data = dialog.get_data()
            try:
                addr_int = int(data["address"], 16)
                row = self.table.rowCount()
                self.table.insertRow(row)
                
                self.table.setItem(row, 0, QTableWidgetItem(hex(addr_int)))
                self.table.setItem(row, 1, QTableWidgetItem(data["name"]))
                self.table.setItem(row, 2, QTableWidgetItem(data["type"]))
                self.table.setItem(row, 3, QTableWidgetItem("N/A"))
                
                self.watches.append({
                    "address": addr_int,
                    "name": data["name"],
                    "type": data["type"],
                    "row": row
                })
            except ValueError:
                QMessageBox.warning(self, "Invalid Input", "Address must be a valid hex string (e.g., 0x1000)")

    def remove_watch(self):
        current_row = self.table.currentRow()
        if current_row >= 0:
            self.table.removeRow(current_row)
            # Remove from self.watches list - need to handle index shifting or rebuild list
            # For simplicity, we'll just rebuild the list from the table or handle it carefully
            # Actually, simpler to just remove by index if we track it, but row indices change.
            # Let's just remove the item that matches the row.
            # A better way for production is to store data in the item or use a model.
            # For this MVP, let's just pop it if we can find it, or better:
            # Rebuild self.watches from table content is safest for simple logic
            self.rebuild_watches()

    def rebuild_watches(self):
        self.watches = []
        for row in range(self.table.rowCount()):
            addr_str = self.table.item(row, 0).text()
            name = self.table.item(row, 1).text()
            type_ = self.table.item(row, 2).text()
            self.watches.append({
                "address": int(addr_str, 16),
                "name": name,
                "type": type_,
                "row": row
            })

    def update_value(self, row, value):
        self.table.setItem(row, 3, QTableWidgetItem(hex(value)))
