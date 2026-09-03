ARG PYTHON_BASE_IMAGE=python:3.12-slim
FROM ${PYTHON_BASE_IMAGE}
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY services/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY services/load-generator /app/load_generator
RUN useradd --uid 10001 --create-home appuser && chown -R appuser:appuser /app
USER 10001
CMD ["python", "-m", "load_generator.main"]
