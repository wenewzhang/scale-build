from logger import logger
    # logger = get_file_logger("MyApp", "/var/log/myapp.log")

def call_logger():
    logger.info("in call_logger")

if __name__ == "__main__":

    call_logger()
    logger.debug("Debug message")
    logger.info("Application started successfully")
    logger.warning("This is a warning message")
    logger.error("An error occurred during processing")
    logger.critical("Critical system failure!")

    print(f"✅ Logs written to /var/log/myapp.log")
    print("   View logs with: tail -f /var/log/myapp.log")
    print("   Or: sudo cat /var/log/myapp.log")
