#!/bin/bash

# Configuración
BACKUP_DIR="$HOME/duckerDots"
LOG_FILE="$BACKUP_DIR/backup_restore_log_$(date +'%Y%m%d_%H%M%S').txt"

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para registrar mensajes en el log
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Función para seleccionar carpetas interactivamente
select_folders() {
    local base_dir="$1"
    local target_dir="$2"
    
    echo -e "${YELLOW}\nSeleccionando carpetas de $base_dir para backup:${NC}"
    
    mkdir -p "$BACKUP_DIR/$target_dir"
    
    for folder in $(ls -A "$base_dir"); do
        if [[ "$folder" == "." || "$folder" == ".." ]]; then
            continue
        fi
        
        read -p "¿Incluir $folder en el backup? [s/n]: " choice
        case "$choice" in
            s|S|y|Y)
                log "Incluyendo $base_dir/$folder en el backup"
                rsync -avz "$base_dir/$folder" "$BACKUP_DIR/$target_dir/" | tee -a "$LOG_FILE"
                ;;
            *)
                log "Omitiendo $base_dir/$folder"
                ;;
        esac
    done
}

# Función para agregar directorios extras
add_extra_directories() {
    echo -e "${YELLOW}\nAgregando directorios extras al backup${NC}"
    echo -e "Ingresa las rutas absolutas de los directorios adicionales a respaldar (uno por línea)"
    echo -e "Presiona Enter en una línea vacía para terminar"
    
    mkdir -p "$BACKUP_DIR/extra-directories"
    
    while true; do
        read -p "> " extra_dir
        if [ -z "$extra_dir" ]; then
            break
        fi
        
        if [ -d "$extra_dir" ]; then
            dir_name=$(basename "$extra_dir")
            log "Agregando directorio extra: $extra_dir"
            rsync -avz "$extra_dir/" "$BACKUP_DIR/extra-directories/$dir_name/" | tee -a "$LOG_FILE"
        else
            log "${RED}El directorio $extra_dir no existe, omitiendo${NC}"
        fi
    done
}

# Función para crear la estructura de directorios
create_backup_structure() {
    log "${YELLOW}Creando estructura de directorios...${NC}"
    
    mkdir -p "$BACKUP_DIR" || {
        log "${RED}Error al crear directorio de backup${NC}";
        exit 1;
    }
    
    local dirs=(
        "config-files"
        "installed-programs"
        "custom-scripts"
        "misc-files"
        "extra-directories"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$BACKUP_DIR/$dir" || {
            log "${RED}Error al crear $dir${NC}";
            exit 1;
        }
    done
    
    log "${GREEN}Estructura de backup creada en $BACKUP_DIR${NC}"
}

# Función para crear backup
create_backup() {
    create_backup_structure
    
    log "${YELLOW}Comenzando backup de configuraciones...${NC}"
    
    # 1. Backup interactivo de .config y .local
    select_folders "$HOME/.config" "config-files/.config"
    select_folders "$HOME/.local/share" "config-files/.local/share"
    
    # 2. Backup de archivos de configuración del sistema
    log "${YELLOW}Copiando configuraciones del sistema...${NC}"
    
    local system_configs=(
        ".bashrc"
        ".zshrc"
        ".profile"
        ".xinitrc"
        ".Xresources"
        ".gitconfig"
        ".vimrc"
        ".tmux.conf"
    )
    
    for config in "${system_configs[@]}"; do
        if [ -f "$HOME/$config" ]; then
            cp -v "$HOME/$config" "$BACKUP_DIR/config-files/" | tee -a "$LOG_FILE"
            log "  → $config"
        fi
    done
    
    # 3. Backup de paquetes instalados
    log "${YELLOW}Generando lista de paquetes...${NC}"
    
    pacman -Qqe > "$BACKUP_DIR/installed-programs/arch-packages.txt"
    log "Lista de paquetes pacman guardada"
    
    if command -v yay >/dev/null; then
        yay -Qqm > "$BACKUP_DIR/installed-programs/aur-packages.txt"
        log "Lista de paquetes AUR guardada"
    fi
    
    if command -v flatpak >/dev/null; then
        flatpak list --columns=application > "$BACKUP_DIR/installed-programs/flatpak-packages.txt"
        log "Lista de flatpaks guardada"
    fi
    
    # 4. Backup de scripts personales
    log "${YELLOW}Copiando scripts personales...${NC}"
    
    if [ -d "$HOME/bin" ]; then
        rsync -avz "$HOME/bin/" "$BACKUP_DIR/custom-scripts/bin/" | tee -a "$LOG_FILE"
        log "  → ~/bin/"
    fi
    
    if [ -d "$HOME/scripts" ]; then
        rsync -avz "$HOME/scripts/" "$BACKUP_DIR/custom-scripts/scripts/" | tee -a "$LOG_FILE"
        log "  → ~/scripts/"
    fi
    
    # 5. Backup misceláneo
    log "${YELLOW}Copiando archivos misceláneos...${NC}"
    
    if [ -d "$HOME/.ssh" ]; then
        mkdir -p "$BACKUP_DIR/misc-files/.ssh"
        cp -v "$HOME/.ssh/config" "$BACKUP_DIR/misc-files/.ssh/" 2>/dev/null
        log "  → .ssh/config (sin claves privadas)"
    fi
    
    # 6. Directorios extras
    add_extra_directories
    
    log "${GREEN}Backup completado con éxito!${NC}"
    log "Directorio listo para subir a GitHub: $BACKUP_DIR"
    log "Comandos para subir a GitHub:"
    log "  cd $BACKUP_DIR"
    log "  git init"
    log "  git add ."
    log "  git commit -m 'Backup de configuraciones'"
    log "  git remote add origin git@github.com:tuusuario/turepo.git"
    log "  git push -u origin main"
}

# [Las funciones restore_configs, show_backup_content y el menú principal permanecen igual...]

# Mostrar menú principal
while true; do
    echo -e "${GREEN}\nGestor de Backup/Restauración para Arch Linux${NC}"
    echo "1. Crear backup de configuraciones"
    echo "2. Restaurar configuraciones desde backup"
    echo "3. Mostrar contenido del backup"
    echo "4. Salir"
    
    read -p "Selecciona una opción (1-4): " choice
    
    case $choice in
        1) create_backup ;;
        2) restore_configs ;;
        3) show_backup_content ;;
        4) exit 0 ;;
        *) echo -e "${RED}Opción no válida${NC}" ;;
    esac
    
    read -p "Presiona Enter para continuar..."
done
