import sys
import logging
from datetime import datetime
from dbt.cli.main import dbtRunner

logging.basicConfig(level=logging.INFO)

runner = dbtRunner()


def invoke(args: list[str]) -> bool:
    start = datetime.now()
    logging.info(f"dbt {' '.join(args)} 시작")

    try:
        result = runner.invoke(args)

        elapsed = datetime.now() - start

        if result.success:
            logging.info(f"성공 ({elapsed})")
            return True

        logging.error(f"실패 ({elapsed})")
        if result.exception:
            logging.error(result.exception)

        return False

    except Exception as e:
        logging.exception(e)
        return False


def run_all():
    if not invoke(["seed"]):
        sys.exit(1)
    if not invoke(["build"]):
        sys.exit(1)
    invoke(["docs", "generate"])


if __name__ == "__main__":
    run_all()